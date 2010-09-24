require 'apps/master/controllers/servant_controller'
require 'apps/master/controllers/login_controller'

module Spider; module Master
    
    class MasterController < Spider::PageController
        include Spider::Auth::AuthHelper
        include StaticContent
        
        layout 'master'
        
        route /customers\/(\d+)\/installations\//, :installations
        route /customers\/(\d+)\/servants\//, :servants
        route /servants\/(\d+)\/plugins\/(\d+)(?:\/(\w+))?(?:\/(.+))?/, :plugin_instance
        #route /servants\/([^\/]+)/, ServantController, :do => lambda{ |id| @request.misc[:servant] = Servant.new(id) }
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
            servant = @servant
            servant ||= instance.servant if instance
            customer = @customer
            customer ||= servant.customer if servant
            @navigation << { :url => "#{Master.url}/customers/#{customer.id}", :name => customer.name } if customer
            @navigation << { :url => "#{Master.url}/customers/#{customer.id}/servants/#{servant.id}", :name => servant.name } if servant
            @navigation << { :url => "#{Master.url}/servants/#{servant.id}/plugins/#{instance.id}", :name => instance.name } if instance
            @navigation << { 
                :url => "#{Master.url}/servants/#{servant.id}/plugins/#{instance.id}/triggers/#{trigger.id}", 
                :name => "#{_('Trigger')} #{trigger.label}"
            } if trigger
            @scene << {
                :trigger => trigger,
                :instance => instance,
                :servant => servant,
                :customer => customer
            }
            super
        end
        
        def check_access(obj)
            customer = nil
            if obj.is_a?(Customer)
                customer = obj
            elsif obj.is_a?(Servant)
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
        def servants(id=nil, customer_id=nil)
            customer_id ||= @request.params['customer']
            customer_id ||= @user.customers[0] unless @user.global?
            available_plugins = Master.scout_plugins.map{ |p| ScoutPlugin.new(p) }
            @scene.available_plugins = available_plugins
            if id
                visual_params[:template] = 'servant'
                @servant = Servant.new(id) if id && id != 'new'
                check_access(@servant) if @servant
                @scene.edit = (@request.params['_w'] && @request.params['_w'].key?('servant_form')) || @request.params.key?('edit') || id == 'new'
                @scene.pk = id
                get_template
                if id == 'new' && @template.widgets[:servant_form]
                    @template.widgets[:servant_form].attributes[:auto_redirect] = Master.url+'/servants'
                else
                    if @request.params['submit_add_plugin']
                        plugin = ScoutPlugin.new(@request.params['plugin'])
                        current = ScoutPluginInstance.where(:servant => @servant, :plugin_id => plugin.id).total_rows
                        name = plugin.name
                        name += " #{current + 1}" if current > 0
                        instance = ScoutPluginInstance.create(:servant => @servant, :plugin_id => plugin.id, :name => name)
                        @servant.scout_plan_changed = DateTime.now
                        @servant.save
                        redirect(@request.path)
                    end
                    if @request.params['remove_plugin']
                        instance = ScoutPluginInstance.load(:id => @request.params['remove_plugin'], :servant => id)
                        instance.delete if instance
                        @servant.scout_plan_changed = DateTime.now
                        @servant.save
                        redirect(@request.path)
                    end
                end
                if customer_id
                    @customer = Customer.new(customer_id) 
                    if @template.widgets[:servant_form]
                        @template.widgets[:servant_form].attributes[:auto_redirect] = Master.url+"/customers/#{customer_id}"
                        @template.widgets[:servant_form].fixed = {:customer => @customer}
                    end
                end
            else
                @scene.servants = Servant.all
                if customer_id
                    @scene.servants.where(:customer => @request.params['customer'])
                end
                visual_params[:template] = 'servants'
            end
        end
        
        __.html
        def plugin_instance(servant_id, id, action=nil, sub_action=nil)
            instance = ScoutPluginInstance.load(:id => id, :servant => servant_id)
            raise NotFound.new("Plugin #{id} for servant #{servant_id}") unless instance
            @servant = Servant.new(:id => servant_id)
            @scene.plugin = instance.plugin
            @instance = instance
            if @request.params['remove_trigger']
                trigger = ScoutPluginTrigger.load(:id => @request.params['remove_trigger'], :plugin_instance => instance)
                trigger.delete if trigger
                redirect @request.path
            end 
            if action == "edit"
                plugin_edit(@servant, @scene.plugin, @instance)
            elsif action == "triggers"
                trigger_edit(sub_action)
            else
                render('plugin_instance')
            end
        end
        
        __.html
        def plugin_edit(servant, plugin, instance)
            if @request.params['submit']
                instance.name = @request.params['name']
                instance.settings = @request.params['settings']
                instance.poll_interval = @request.params['poll_interval'] unless @request.params['poll_interval'].blank?
                instance.timeout = @request.params['timeout'] unless @request.params['timeout'].blank?
                instance.save
                redirect("#{Master.url}/servants/#{@servant.id}/plugins/#{@instance.id}")
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
                raise NotFound.new("Trigger #{id} of servant #{@scene.servant}") unless trigger
            end
            @trigger = trigger
            if @request.params['submit'] && (id != 'new' || @request.params['data'])
                @request.params.each do |k, v|
                    next if ['trigger_type', 'data'].include?(k) && trigger.id
                    trigger.set(k, v) if trigger.class.elements[k.to_sym]
                end
                trigger.save
                redirect("#{Master.url}/servants/#{@servant.id}/plugins/#{@instance.id}")
            end
            render 'trigger_edit'
        end
        
        __.action
        def ping
            servant_id = @request.params['servant_id']
            servant = Master::Servant.load(:id => servant_id)
            new_servant = false
            unless servant
                servant = Master::Servant.static(:id => servant_id)
                new_servant = true
            end
            servant.last_check = DateTime.now
            servant.name = @request.params['servant_name']
            servant.system_status = @request.params['system_status']
            curr_resources = servant.resources_by_type
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
            servant.resources = resources
            if new_servant
                servant.insert
            else
                servant.update
            end
            response = {
                :pong => DateTime.new
            }
            servant.pending_commands.each do |command|
                response[:commands] ||= []
                response[:commands] << command.to_h
            end
            $out << response.to_json
        end
        
    end
    
end; end