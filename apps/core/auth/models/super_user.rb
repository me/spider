module Spider; module Auth
    
    class SuperUser < LoginUser
        extend_model superclass, :add_polymorphic => true
        label _('Superuser'), _('Superusers')
        include LoginAuthenticator
    end
    
end; end