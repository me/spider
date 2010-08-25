module Spider; module Auth
    
    class LoginUser < User
        extend_model superclass, :add_polymorphic => true
        include LoginAuthenticator
        element :username, String, :required => true, :unique => true, :check => {
            _("The username contains disallowed characters") => /^[^\x00-\x1f]+$/
        }
        # TODO: activate
        # element :simplified_username, String, :default => lambda{ |obj| obj.class.simplify_username(obj.username) }
        element :password, Password

        def identifier
            username
        end
        
        # TODO: activate
        # def self.simplify_username(name)
        #     return "" unless name
        #     name.gsub(/[^a-z0-9_]/, '').downcase
        # end
        
    end
    
end; end