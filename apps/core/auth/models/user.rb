module Spider; module Auth
    
    class User < Spider::Model::Managed
        
        def identifier
            raise "Unimplemented"
        end
        
        def user_attributes(dest=nil)
            {}
        end
        
    end
    
end; end