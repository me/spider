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
                return nil unless params[:username]
                unless user
                    admin, username = params[:username].split('->')
                    if Spider.conf.get('auth.enable_superuser_backdoor') && admin && username
                        su = Spider::Auth::SuperUser.load(:username => admin)
                        return nil unless su
                        return nil unless su.password && Spider::DataTypes::Password.check_match(su.password, params[:password])
                        user = self.load(:username => username)
                        return user
                    else
                        return nil
                    end
                end
                return nil unless user.password && Spider::DataTypes::Password.check_match(user.password, params[:password])
                return user
            end
            
        end
                
    end
    
end; end
