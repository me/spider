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
        
        __.html
        def index
            @scene.redirect = @request.params['redirect'] if (@request.params['redirect'])
            @scene.unauthorized_msg = @request.session.flash[:unauthorized_exception].message if @request.session.flash[:unauthorized_exception] && @request.session.flash[:unauthorized_exception].message != 'Spider::Auth::Unauthorized'
            @scene.message = @request.session.flash[:login_message] if @request.session.flash[:login_message]
            render('login')
        end
        
        def authenticate
            get_user
        end
        
        def get_user
            return self.class.user.authenticate(:login, :username => @request.params['login'], :password => @request.params['password'])
        end
        
        __.html
        def do_login
            user = authenticate
            if (user)
                user.save_to_session(@request.session)
                unless success_redirect
                    $out << "Loggato"
                end
            else
                @scene.failed_login = true
                @response.status = 401
                @scene.login = @request.params['login']
                index
            end
        end
        
        def success_redirect
            if (@request.params['redirect'] && !@request.params['redirect'].empty?)
                redir_to = @request.params['redirect']
                redirect(redir_to, Spider::HTTP::SEE_OTHER)
                return true
            elsif(self.default_redirect)
                redirect(self.default_redirect)
                return true
            else
                return false
            end
        end
        
        __.html
        def logout
            @request.session[:auth] = nil
            @scene.did_logout = true
            render('login')
        end
        
    end
    
    
end; end
