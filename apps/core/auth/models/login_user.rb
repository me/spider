module Spider; module Auth
    
    class LoginUser < User
        element :username, String, :unique => true
        element :password, Password

        
    end
    
end; end