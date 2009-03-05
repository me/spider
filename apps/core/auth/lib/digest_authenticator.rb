require 'apps/core/auth/lib/authenticator'
require 'digest/md5'

module Spider; module Auth
    
    class DigestAuthenticator < Authenticator
        
        def authenticate(login, password, realm)
            ha1 = self.ha1(login, password, realm)
            user = DigestUser.find(:username => login, :realm => realm, :ha1 => ha1)
            if (user.length == 1)
                return user[0].uid
            end
            return nil
        end
        
        def find_by_ha1
            user = DigestUser.find(:ha1 => ha1)
            return user[0] if (user.length == 1)
            return nil
        end
        
        def find(login, realm)
            users = DigestUser.find(:username => login, :realm => realm)
            users.load
            if (users.length == 1)
                return users[0]
            end
            return nil
        end
        
        def ha1(login, password, realm)
            Digest::MD5::hexdigest("#{login}:#{password}:#{realm}")
        end
        
    end
    
end; end