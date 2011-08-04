require 'apps/master/controllers/server_controller'
require 'apps/master/controllers/login_controller'
require 'json'
require 'socket'


module Spider; module Master
    
    class MasterController < Spider::PageController
        include Spider::Auth::AuthHelper
        include StaticContent
        
        layout 'master'
        
        route /customers\/(\d+)\/installations\//, :installations
        route /customers\/(\d+)\/servers\//, :servers
        route /servers\/(\d+)\/plugins\/(\d+)(?:\/(\w+))?(?:\/(.+))?/, :plugin_instance
        route /servers\/(\d+)\/sites\/(\d+|new|create)(?:\/(\w+))?(?:\/(.+))?/, :site
        #route /servers\/([^\/]+)/, ServerController, :do => lambda{ |id| @request.misc[:server] = Server.new(id) }
        route 'login', LoginController
        
        require_user Master::Admin, :unless => [:login, :admin, :ping, :servant_event], :redirect => 'login'
        require_user Spider::Auth::SuperUser, :only => [:admin]
        
        
        def before(action='', *args)
            super
            @user = @request.auth(Master::Admin)
            @scene.user = @user
            @navigation = []
            @scene.navigation = @navigation
        end
                
        __.html :template => 'index'
        def index
            customers = @user.customers
            if customers.length == 1
                redirect "customers/#{customers[0].id}"
            else
                redirect "customers"
            end
        end
    
        __.html :template => 'admin', :layout => 'admin', :action_to => :admin
        def admin
        end
        
        def load_customer(id)
            customer = Customer.new(id)
            check_access(customer)
        end
        
        def prepare_scene(scene)
            @navigation << {:url => "#{Master.url}/customers", :name => _("Customers") } if @user.global?
            trigger = @trigger
            instance = @instance
            instance ||= trigger.instance if trigger
            server = @server
            server ||= instance.server if instance
            customer = @customer
            customer ||= server.customer if server
            @navigation << { :url => "#{Master.url}/customers/#{customer.id}", :name => customer.name } if customer
            @navigation << { :url => "#{Master.url}/customers/#{customer.id}/server/#{server.id}", :name => server.name } if server
            @navigation << { :url => "#{Master.url}/servers/#{server.id}/plugins/#{instance.id}", :name => instance.name } if instance
            @navigation << { 
                :url => "#{Master.url}/servers/#{server.id}/plugins/#{instance.id}/triggers/#{trigger.id}", 
                :name => "#{_('Trigger')} #{trigger.label}"
            } if trigger
            @scene << {
                :trigger => trigger,
                :instance => instance,
                :server => server,
                :customer => customer
            }
            super
        end
        
        def check_access(obj)
            customer = nil
            if obj.is_a?(Customer)
                customer = obj
            elsif obj.is_a?(Server)
                customer = obj.customer
            end
            raise Spider::Auth::Unauthorized.new(_("No customer")) if !customer && !@user.global?
            unless @user.can_manage_customer?(customer)
                raise Spider::Auth::Unauthorized.new(_("User can't access this customer"))     
            end
            obj
        end
        
        
        __.html
        def customers(id=nil)
            if id
                visual_params[:template] = 'customer'
                @customer = load_customer(id) if id && id != 'new'
                @scene.edit = (@request.params['_w'] && @request.params['_w'].key?('customer_form')) || @request.params.key?('edit') || id == 'new'
                @scene.pk = id
                get_template
                if id == 'new' && @template.widgets[:customer_form]
                    @template.widgets[:customer_form].attributes[:auto_redirect] = Master.url+'/customers'
                end
            else
                unless @user.can_manage_customers?
                    raise Spider::Auth::Unauthorized.new(_("User can't list customers")) 
                end
                @scene.customers = @user.customers.map{ |c| c.customer }
                visual_params[:template] = 'customers'
            end
        end
        
        
        
        __.html :template => 'installation'
        def installs(id=nil, customer_id=nil)
            @customer = load_customer(customer_id) if customer_id
            if id
                @installation = Installation.new(id) unless id == 'new'
                @scene.edit = (@request.params['_w'] && @request.params['_w'].key?('installation_form')) || @request.params.key?('edit') || id == 'new'
                @scene.pk = id
                
                if @request.params['add_command']
                    command = @request.params['command']
                    args = @request.params['arguments']
                    arguments = args
                    # FIXME: move somewhere else
                    case command
                    when 'gems', 'apps'
                        arguments = args.split(/\s*,\s*/).to_json
                    end
                    Master::Command.create(
                        :installation => @installation,
                        :name => @request.params['command'],
                        :arguments => arguments,
                        :status => 'pending'
                    )
                    redirect(@request.path)
    
                end
                @scene.install_apps = JSON.parse(@installation.apps) unless @installation.apps.blank?
                @scene.install_apps ||= []
                @scene.apps = Spider::AppServer.apps_by_id
                @scene.logs = RemoteLog.where(:installation => @installation)
                @scene.commands = Master::Command.where{ |c| (c.installation == @installation) }.order_by(:obj_created)
                @scene.available_commands = {
                    'gems' => _('Install or update gems'),
                    'apps' => _('Install or update apps')
                }
                @scene << {
                    :customer => @customer,
                    :installation => @installation
                }
            end
        end
        
        __.html
        def servers(id=nil, customer_id=nil)
            customer_id ||= @request.params['customer']
            customer_id ||= @user.customers[0] unless @user.global?
            available_plugins = Master.scout_plugins.map{ |p| ScoutPlugin.new(p) }
            @scene.available_plugins = available_plugins
            if id
                visual_params[:template] = 'server'
                @server = Server.new(id) if id && id != 'new'
                check_access(@server) if @server
                @scene.edit = (@request.params['_w'] && @request.params['_w'].key?('server_form')) || @request.params.key?('edit') || id == 'new'
                @scene.pk = id
                get_template
                if id == 'new' && @template.widgets[:server_form]
                    @template.widgets[:server_form].attributes[:auto_redirect] = Master.url+'/servers'
                else
                    if @request.params['submit_add_plugin']
                        plugin = ScoutPlugin.new(@request.params['plugin'])
                        current = ScoutPluginInstance.where(:server => @server, :plugin_id => plugin.id).total_rows
                        name = plugin.name
                        name += " #{current + 1}" if current > 0
                        instance = ScoutPluginInstance.create(:server => @server, :plugin_id => plugin.id, :name => name)
                        @server.scout_plan_changed = DateTime.now
                        @server.save
                        redirect(@request.path)
                    end
                    if @request.params['remove_plugin']
                        instance = ScoutPluginInstance.load(:id => @request.params['remove_plugin'], :server => id)
                        instance.delete if instance
                        @server.scout_plan_changed = DateTime.now
                        @server.save
                        redirect(@request.path)
                    end
                end
                if customer_id
                    @customer = Customer.new(customer_id) 
                    if @template.widgets[:server_form]
                        @template.widgets[:server_form].attributes[:auto_redirect] = Master.url+"/customers/#{customer_id}"
                        @template.widgets[:server_form].fixed = {:customer => @customer}
                    end
                end
            else
                @scene.servers = Server.all
                if customer_id
                    @scene.servers.where(:customer => @request.params['customer'])
                end
                visual_params[:template] = 'servers'
            end
        end
        
        __.html
        def plugin_instance(server_id, id, action=nil, sub_action=nil)
            instance = ScoutPluginInstance.load(:id => id, :server => server_id)
            raise NotFound.new("Plugin #{id} for server #{server_id}") unless instance
            @server = Server.new(:id => server_id)
            @scene.plugin = instance.plugin
            fields = []
            last = instance.last_reported
            if last
                fields = last.fields.map{ |f| f.name }
            end
            @scene.last_reported = last
            @scene.fields = fields
            @scene.last = last
            labels = {}
            fields.each{ |key|
                labels[key] = instance.metadata[key] && instance.metadata[key]["label"] ? \
                    instance.metadata[key]["label"] : key
            }
            @scene.labels = labels
            @scene.metadata = instance.metadata
            @instance = instance
            if instance.status.id.to_sym == :error
                @scene.last_error = instance.last_error
            end
            if @request.params['remove_trigger']
                trigger = ScoutPluginTrigger.load(:id => @request.params['remove_trigger'], :plugin_instance => instance)
                trigger.delete if trigger
                redirect @request.path
            end 
            if action == "edit"
                plugin_edit(@server, @scene.plugin, @instance)
            elsif action == "triggers"
                trigger_edit(sub_action)
            elsif action == "data"
                plugin_data(instance, sub_action)
            else
                render('plugin_instance')
            end
        end
        
        __.html
        def site(server_id, id, action=nil, sub_action=nil)
            if @request.params['submit']
            end
            @server = Server.new(server_id)
            @scene.site_type = @request.params['site_type']
            if @request.params['edit'] || id == 'new' || id == 'create'
                render('site_edit')
            else
                render('site')
            end
        end
        
        __.html
        def plugin_edit(server, plugin, instance)
            if @request.params['submit']
                instance.name = @request.params['name']
                instance.settings = @request.params['settings']
                instance.poll_interval = @request.params['poll_interval'] unless @request.params['poll_interval'].blank?
                instance.timeout = @request.params['timeout'] unless @request.params['timeout'].blank?
                instance.save
                redirect("#{Master.url}/server/#{@server.id}/plugins/#{@instance.id}")
            end
            render('plugin_edit')
        end
        
        __.html
        def trigger_edit(id)
            if id == 'new'
                trigger = ScoutPluginTrigger.new(:plugin_instance => @instance)
                trigger.trigger_type = @request.params['trigger_type']
                trigger.data = @request.params['data_series']
            else
                trigger = ScoutPluginTrigger.load(:id => id, :plugin_instance => @instance)
                raise NotFound.new("Trigger #{id} of server #{@scene.server}") unless trigger
            end
            @trigger = trigger
            if @request.params['submit'] && (id != 'new' || @request.params['data'])
                @request.params.each do |k, v|
                    next if ['trigger_type', 'data'].include?(k) && trigger.id
                    trigger.set(k, v) if trigger.class.elements[k.to_sym]
                end
                trigger.save
                redirect("#{Master.url}/server/#{@server.id}/plugins/#{@instance.id}")
            end
            render 'trigger_edit'
        end
        
        def plugin_data(instance, key)
            return chart_data(instance) if key == 'chart_data'
            @scene.key = key
            @scene.label = instance.plugin.metadata[key]["label"] if instance.plugin.metadata[key]
            @scene.label = key if @scene.label.blank?
            @scene.values = ScoutReportField.where('report.plugin_instance' => instance, :name => key)
            render 'plugin_data'
        end
        
        def chart_data(instance)
            key = @request.params["data"]
            columns = [[instance, key]]
            if @request.params["compare"]
                columns += @request.params["compare"].map do |c|
                    instance_id, c_key = c.split('|')
                    [ScoutPluginInstance.new(instance_id), c_key]
                end
            end
            res = {
                :labels => columns.map{ |i, k| i.plugin.label(k) }
            }
            data = {}
            columns.each_with_index do |pair, i|
                inst, k = pair
                values = ScoutReportField.where(:plugin_instance => inst, :name => k)
                values.request.merge!(:name => true, :value => true)
                values.each do |v|
                    data[v.report_date] ||= []
                    data[v.report_date][i] = v.value
                    
                end
            end
            data = data.map{ |k, v| [k] + v }.sort{ |a, b| a[0] <=> b[0] }
            res[:data] = data 
            content_type :json
            $out << res.to_json
        end
        
        __.json
        def ping
            install_id = @request.params['install_id']
            unless install_id
                Spider.logger.error("No install_id passed in ping")
                done
            end
            install = Spider::Master::Installation.load_or_create(:uuid => install_id)
            install.last_check = DateTime.now
            install.apps = @request.params['apps']
            install.interval = @request.params['interval']
            install.configuration = decompress_string(@request.params['configuration'])
            curr_ip = install.ip_address
            install.ip_address = @request.env['REMOTE_ADDR']
            if install.ip_address != curr_ip
                install.hostname = Socket::getaddrinfo(install.ip_address,nil)[0][2]
            end
            install.save
            log_lines = JSON.parse(@request.params['log'])
            log_lines.each do |log|
                time, level, desc = *log
                time = Time.parse(time)
                next if log[2] =~ /^Not found/
                RemoteLog.create(:text => desc, :level => level, :time => time, :installation => install)
            end
            response = {
                :pong => DateTime.now
            }
            commands = []
            Master::Command.where{ |c| (c.installation == install) & (c.status == 'pending') }.each do |c|
                commands << {
                    :id => c.uuid,
                    :name => c.name,
                    :arguments => c.arguments ? JSON.parse(c.arguments) : nil
                }
            end
            response[:commands] = commands unless commands.empty?
            $out << response.to_json
            Master::Command.where{ |c| (c.installation == install) & (c.status == 'pending') }.each do |c|
                c.sent = DateTime.now
                c.status = 'sent'
                c.save
            end
        end
        
        __.json
        def servant_event
            params = @request.params.clone
            name = params.delete('event')
            install_id = params.delete('install_id')
            unless install_id
                Spider.logger.error("No install_id passed in ping")
                done
            end
            install = Spider::Master::Installation.load_or_create(:uuid => install_id)
            details = @request.params['details']
            params = JSON.parse(details)
            Event.create(
                :installation => install,
                :name => name,
                :details => details
            )
            case name.to_sym
            when :command_done
                cmd = Master::Command.load(:uuid => params['id'])
                cmd.done = DateTime.now
                cmd.result = params['res'].to_json
                cmd.status = 'success'
                cmd.save
            when :plan_done
                results = params['results']
                results.each do |res|
                    cmd = Master::Command.load(:uuid => res['command_id'])
                    if res['previous_error']
                        cmd.status = 'not_done'
                        cmd.save
                    elsif res['error']
                        cmd.status = 'error'
                        cmd.save
                    end
                end
            end
        end
        
        
        
        private
        
        def decompress_string(str)
            Zlib::GzipReader.new(StringIO.new(str)).read
        end
        
    end
    
end; end
