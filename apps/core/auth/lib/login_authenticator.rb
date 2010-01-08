require 'apps/core/auth/lib/authenticable'

module Spider; module Auth
    
    module LoginAuthenticator
        include Authenticable
        
        def self.included(klass)
            klass.extend(ClassMethods)
            klass.extend(Authenticable::ClassMethods)
            klass.register_authentication(:login)
        end
        
        module ClassMethods
            
            def authenticate_login(params)
                user = self.load(:username => params[:username])
                return nil unless user
                return nil unless user.password && Spider::DataTypes::Password.check_match(user.password, params[:password])
                return user
            end
            
        end
                
    end
    
end; end