module Spider
    
    module RestModel
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        module ClassMethods
            
            def rest_model(var, options={})
                
            end
            
        end
        
    end
    
    
end