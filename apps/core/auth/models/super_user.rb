module Spider; module Auth
    
    class SuperUser < LoginUser
        extend_model superclass, :add_polymorphic => true
        include LoginAuthenticator
    end
    
end; end