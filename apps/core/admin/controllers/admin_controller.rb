module Spider; module Admin

    class LoginController < Spider::Auth::LoginController
        
        layout 'login'
        
        def before(action='', *params)
            @scene.login_title = _("Administration")
            super
        end
        
        def self.users
            Spider::Admin.allowed_users
        end

        
        def self.default_redirect
            AdminController.url
        end
        
        def self.logout_redirect
            AdminController.url('login')
        end
    end
    
    class AdminController < Spider::PageController
        layout 'admin'

        include Spider::Auth::AuthHelper
        include StaticContent

        def self.auth_require_users
            [[Spider::Admin.allowed_users, {:unless => [:login], :redirect => 'login'}]]
        end
        
        route 'login', LoginController


        def before(action='', *params)
            super
            
            return if serving_static?(action)
            @scene.username = @request.user.username if @request.user
            @scene.apps = []
            Admin.apps.each do |short_name, app|
                unless @request.user.superuser?
                    next if app[:options][:users] && !app[:options][:users].include?(@request.user.class)
                end
                url = self.class.http_url(short_name)
                @scene.apps << {
                    :icon => app[:module].pub_url+'/'+app[:options][:icon],
                    :url => self.class.http_url(short_name),
                    :name => app[:module].full_name,
                    :description => app[:module].description,
                    :module => app[:module],
                    :priority => app[:options][:priority] || 1
                }
            end
            @scene.admin_breadcrumb = []
            @scene.admin_breadcrumb << {:url => self.class.url, :label => _('Home')} if @scene.apps.length > 1

            # FIXME
            @scene.apps.sort!{ |a,b| a[:priority] <=> b[:priority] }
        end

        __.html :template => 'index'
        def index
        end
        
    end
    
    
end; end