require 'apps/core/auth/lib/login_authenticator'

module Spider; module Auth
    
    class LoginController < Spider::Controller
        include HTTPMixin
        include Visual
        
        def self.user
            LoginUser
        end
        
        def self.default_redirect
            nil
        end
        
        def before(action='')
            super
            @response.headers['Content-Type'] = 'text/html'
        end
        
        def index
            @scene.redirect = @request.params['redirect'] if (@request.params['redirect'])
            render('login')
        end
        
        def do_login
            user = self.class.user.authenticate(:login, :username => @request.params['login'], :password => @request.params['password'])
            if (user)
                user.save_to_session(@request.session)
                if (@request.params['redirect'] && !@request.params['redirect'].empty?)
                    redir_to = @request.params['redirect']
                    redirect(redir_to)
                elsif(self.class.default_redirect)
                    redirect(self.class.default_redirect)
                else
                    $out << "Loggato"
                end
            else
                @scene.failed_login = true
                @scene.login = @request.params['login']
                index
            end
        end
        
        def logout
            @request.session[:auth] = nil
            @scene.did_logout = true
            render('login')
        end
        
    end
    
    
end; end