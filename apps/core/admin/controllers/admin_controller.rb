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
            AdminController.http_url('login')
        end
    end
    
    class AdminController < Spider::PageController
        layout 'admin'

        include Spider::Auth::AuthHelper
        include StaticContent

        def self.auth_require_users
            users = super
            params = {:unless => [:login], :redirect => 'login'}
            if users.empty?
                [[Spider::Admin.allowed_users, params]]
            else
                users.map{ |u| [u[0], params.merge(u[1])]}
            end
        end
        
        route 'login', LoginController


        def before(action='', *params)
            super
            
            return if serving_static?(action)
            return unless @request.user
            @scene.username = @request.user.username
            @scene.apps = []
            Admin.apps.each do |short_name, app|
                unless @request.user.superuser?
                    next if app[:options][:users] && !app[:options][:users].include?(@request.user.class)
                end
                url = self.class.http_url(short_name)
                @scene.apps << {
                    :icon => app[:options][:icon] ? app[:module].pub_url+'/'+app[:options][:icon] : nil,
                    :url => self.class.http_url(short_name),
                    :name => app[:module].full_name,
                    :description => app[:module].description,
                    :module => app[:module],
                    :priority => app[:options][:priority] || 1
                }
            end
            @scene.admin_breadcrumb = []
            @scene.admin_breadcrumb << {:url => self.class.http_url, :label => _('Home')} if @scene.apps.length > 1

            # FIXME
            @scene.apps.sort!{ |a,b| b[:priority] <=> a[:priority] }
        end

        __.html :template => 'index'
        def index
        end
        
    end
    
    
end; end
