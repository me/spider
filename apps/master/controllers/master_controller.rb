require 'apps/master/controllers/server_controller'
require 'apps/master/controllers/login_controller'
require 'json'


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
        
        require_user Master::Admin, :unless => [:login, :admin], :redirect => 'login'
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
        def installations(id, customer_id)
            @customer = load_customer(customer_id)
            @installation = Installation.new(id) unless id == 'new'
            if id == 'new'
                if @request.params.key?('installation_create') && !@request.params['installation_name'].empty?
                    i = Installation.new(:name => @request.params['installation_name'])
                    i.customer = @customer
                    i.save
                    redirect(File.dirname(@request.path)+"/#{i.id}")
                end
            else
                if @request.params.key?('save_apps')
                    @installation.apps = @request.params['apps'].keys.join(',')
                    @installation.save
                    redirect(request.path)
                end
                @scene.install_apps = (@installation.apps && !@installation.apps.empty?)  ? @installation.apps.split(',') : []
                @scene.apps = Spider::AppServer.apps
            end
            @scene << {
                :customer => @customer,
                :installation => @installation
            }
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
        
        __.action
        def ping
            server_id = @request.params['server_id']
            server = Master::Server.load(:id => server_id)
            new_server = false
            unless server
                server = Master::Server.static(:id => server_id)
                new_server = true
            end
            server.last_check = DateTime.now
            server.name = @request.params['server_name']
            server.system_status = @request.params['system_status']
            curr_resources = server.resources_by_type
            resources = []
            if @request.params['resources']
                @request.params['resources'].each do |res_type, type_resources|
                    type_resources.each do |name, details|
                        if curr_resources[res_type]
                            res = curr_resources[res_type][name]
                        end
                        res ||= Resource.static
                        res.resource_type = res_type
                        res.name = name
                        res.description = details['description']
                        res.save
                        resources << res
                    end
                end
            end
            server.resources = resources
            if new_server
                server.insert
            else
                server.update
            end
            response = {
                :pong => DateTime.new
            }
            server.pending_commands.each do |command|
                response[:commands] ||= []
                response[:commands] << command.to_h
            end
            $out << response.to_json
        end
        
    end
    
end; end
