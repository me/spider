require 'apps/core/auth/lib/authenticator'
require 'digest/md5'

module Spider; module Auth
    
    module DigestAuthenticator
        include Authenticable
        
        def self.included(klass)
            klass.extend(ClassMethods)
            klass.extend(Authenticable::ClassMethods)
            klass.register_authentication(:digest)
        end
        
        module ClassMethods
        
            def authenticate_digest(params)
                login = params[:login]
                password = params[:password]
                realm = password[:ha1]
                ha1 = self.ha1(login, password, realm)
                user = find(:username => login, :realm => realm, :ha1 => ha1)
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
        
            def ha1(login, password, realm)
                Digest::MD5::hexdigest("#{login}:#{password}:#{realm}")
            end
            
            
        end
        
    end
    
end; end