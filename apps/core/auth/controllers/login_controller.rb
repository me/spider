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
        
        def default_redirect
            self.class.default_redirect
        end
        
        def before(action='')
            super
            @response.headers['Content-Type'] = 'text/html;charset=UTF-8'
        end
        
        def index
            @scene.redirect = @request.params['redirect'] if (@request.params['redirect'])
            @scene.unauthorized_msg = @request.session.flash[:unauthorized_exception].message if @request.session.flash[:unauthorized_exception] && @request.session.flash[:unauthorized_exception].message != 'Spider::Auth::Unauthorized'
            render('login')
        end
        
        def do_login
            user = self.class.user.authenticate(:login, :username => @request.params['login'], :password => @request.params['password'])
            if (user)
                user.save_to_session(@request.session)
                if (@request.params['redirect'] && !@request.params['redirect'].empty?)
                    redir_to = @request.params['redirect']
                    redirect(redir_to, Spider::HTTP::SEE_OTHER)
                elsif(self.default_redirect)
                    redirect(self.default_redirect)
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
