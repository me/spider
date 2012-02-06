require 'apps/core/auth/lib/login_authenticator'

module Spider; module Auth
    
    class LoginController < Spider::Controller
        include HTTPMixin
        include Visual
        
        def self.default_redirect
            nil
        end
        
        def self.logout_redirect
            nil
        end
        
        def self.users=(val)
            @user_classes = val
        end
        
        def self.users
            @user_classes ||= [Spider::Auth::SuperUser]
        end
        
        def default_redirect
            self.class.default_redirect
        end
                
        __.html
        def index
            exception = @request.session.flash[:unauthorized_exception]
            @scene.redirect = @request.params['redirect'] if (@request.params['redirect'])
            @scene.unauthorized_msg = exception[:message] if exception && exception[:message] != 'Spider::Auth::Unauthorized'
            @scene.message = @request.session.flash[:login_message] if @request.session.flash[:login_message]
            render('login')
        end
        
        def authenticate(params={})
            get_user
        end
        
        def get_user
            self.class.users.each do |user|
                u = user.authenticate(:login, :username => @request.params['login'], :password => @request.params['password'])
                return u if u
            end
            return nil
        end
        
        __.html
        def do_login
            user = authenticate
            if user
                user.save_to_session(@request.session)
                on_success(user)
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
        
        def on_success(user)
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
            red = self.class.logout_redirect
            if red
                redirect(red)
            else
                redirect('index')
            end
        end
        
    end
    
    
end; end
