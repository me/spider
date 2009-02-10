module Spider; module Auth
    
    class LoginUser < User
        element :login, String, :unique => true
        element :password, Password

        
    end
    
end; end