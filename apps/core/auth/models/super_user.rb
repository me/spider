module Spider; module Auth
    
    class SuperUser < LoginUser
        extend_model superclass, :add_polymorphic => true
        label _('Superuser'), _('Superusers')
        include LoginAuthenticator


        def superuser?
            true
        end

    end
    
end; end