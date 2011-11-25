module Spider; module Auth
    
    class User < Spider::Model::Managed
        
        def identifier
            raise "Unimplemented"
        end
        
        def user_attributes(dest=nil)
            {}
        end

        # This can be overrided in subclasses, possibly with RBACProvider
        def can?(*args)
            false
        end

        def superuser?
            false
        end
        
    end
    
end; end