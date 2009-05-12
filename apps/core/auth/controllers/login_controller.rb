require 'apps/core/auth/lib/login_authenticator'

module Spider; module Auth
    
    class LoginController < Spider::Controller
        include HTTPMixin
        include Visual
        
        def self.authenticator
            LoginAuthenticator.new
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
            authenticator = self.class.authenticator
            uid = authenticator.authenticate(@request.params['login'], @request.params['password'])
            if (uid)
                @request.session['uid'] = uid
                Spider::Logger.debug("SESSION:")
                Spider::Logger.debug(@request.session)
                Spider::Auth.current_user = uid
                if (@request.params['redirect'] && !@request.params['redirect'].empty?)
                    redir_to = @request.params['redirect']
                    redirect(redir_to)
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
            @request.session['uid'] = nil
            Spider::Auth.current_user = nil
        end
        
    end
    
    
end; end