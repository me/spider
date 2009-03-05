require 'apps/core/auth/lib/authenticator'

module Spider; module Auth
    
    class LoginAuthenticator < Authenticator
        
        def authenticate(login, password)
            user = LoginUser.find(:username => login, :password => password)
            if (user.length == 1)
                return user[0].uid
            end
            return nil
        end
        
    end
    
end; end