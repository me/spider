require 'apps/core/auth/_init.rb'

module Spider; module Components
    
    # This widget creates an administration page for models.
    #
    # Attributes:
    # *:models*     Comma-separated list of model names
    # *:title*
    # *:logout_url* 
    #
    # Content:
    # Takes the tags
    # *admin:model*     A model to administer
    # *admin:app*       Administer all models belonging to the app. Can have an 'except' attribute.
    
    class Admin < Spider::Widget
        tag 'admin'
        
        i_attribute :models, :process => lambda{ |models| models.split(/,[\s\n]*/).map{|m| const_get_full(m) } }
        is_attr_accessor :title, :default => lambda{ _("Administration") }
        is_attr_accessor :logout_url, :default => Spider::Auth.request_url+'/login/logout'
        is_attr_accessor :"full-page", :type => Spider::Bool, :default => false
        attr_accessor :custom_widgets
        
        def init
            @items = []
        end
        
        def route_widget
            [:switcher, @_action]
        end
        
        def prepare_widgets
            @models.each do |model|
                if @user_checks && user_check = @user_checks[model]
                    next unless @request.user
                    next unless @request.user.respond_to?(user_check)
                    next unless @request.user.send(user_check)
                end
                crud = Crud.new(@request, @response)
                crud.id = model.name.to_s.gsub('::', '_').downcase
                crud.model = model
                if @custom_widgets && @custom_widgets[model]
                    crud.table_widget = @custom_widgets[model][:table] if @custom_widgets[model][:table]
                    crud.form_widget = @custom_widgets[model][:form] if @custom_widgets[model][:form]
                end
                @widgets[:switcher].add(model.label_plural, crud, _('Manage Data'))
            end
            if (@request.respond_to?(:user) && @request.user)
                @scene.username = @request.user.to_s
            else
                @scene.username = _("guest")
                @scene.guest = true
            end
            super
        end
        
        def run
            @scene.current = @widgets[:switcher].current_label
            if @scene._parent.admin_breadcrumb
                @scene.breadcrumb = @scene._parent.admin_breadcrumb
                bc = []
                bc << {:label => @scene.current, :url => @widgets[:switcher].link(@scene.current)}
                if @widgets[:switcher].current.action == :form
                    bc += @widgets[:switcher].current.form.breadcrumb
                end
                @scene.breadcrumb.concat(bc)
            end
            super
        end
        
        def self.parse_content(doc)
            assets_widgets = []
            doc.search('admin:model').each do |mod|
                if table = mod.get_attribute('table')
                    assets_widgets << table 
                end
                if form = mod.get_attribute('form')
                    assets_widgets << form 
                end
            end
            assets_widgets.uniq!
            rc, ov = super
            unless assets_widgets.empty?
                ov << Hpricot("<tpl:prepend><tpl:assets widgets=\"#{assets_widgets.uniq.join(',')}\"></tpl:prepend>").root
            end
            [rc, ov]
        end
        
        def parse_runtime_content(doc, src_path)
            @custom_widgets ||= {}
            @user_checks ||= {}
            doc = super
            mods = []
            doc.search('admin:model').each do |mod|
                model = const_get_full(mod.innerText)
                mods << model
                if table = mod.get_attribute('table')
                    @custom_widgets[model] ||= {}
                    @custom_widgets[model][:table] = table
                end
                if form = mod.get_attribute('form')
                    @custom_widgets[model] ||= {}
                    @custom_widgets[model][:form] = form
                end
                if user_check = mod.get_attribute('if-user')
                    @user_checks[model] = user_check.to_sym
                end
            end
            doc.search('admin:app').each do |app_tag|
                except = []
                if (app_tag.attributes['except'])
                    except = app_tag.attributes['except'].split(',').map{ |e| e.strip }
                end
                app = const_get_full(app_tag.innerText.strip)
                mods += app.models.select{ |m|
                    !m.attributes[:sub_model] && m.mapper.class.write? && !except.include?(m.name.split('::')[-1])
                }.sort{ |a, b| a.name <=> b.name }
            end
            @models ||= []
            @models += mods
            return doc
        end

    end
    
end; end
