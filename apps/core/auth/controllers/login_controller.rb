require 'apps/core/auth/lib/login_authenticator'

module Spider; module Auth
    
    class LoginController < Spider::Controller
        include HTTPMixin
        include Visual
        
        def before(action='')
            super
            @response.headers['Content-Type'] = 'text/html'
        end
        
        def index
            @request.session['login_redirect'] = @request.params['redirect'] if (@request.params['redirect'])
            render('login')
        end
        
        def do_login
            authenticator = LoginAuthenticator.new
            uid = authenticator.authenticate(@request.params['login'], @request.params['password'])
            if (uid)
                @request.session['uid'] = uid
                Spider::Logger.debug("SESSION:")
                Spider::Logger.debug(@request.session)
                Spider::Auth.current_user = uid
                if (@request.session['login_redirect'])
                    redir_to = @request.session['login_redirect']
                    @request.session.delete('login_redirect')
                    redirect(redir_to)
                else
                    $out << "OK! LOGGATO!"
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