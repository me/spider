module Spider
    
    module ControllerMixin
        
        def self.included(mod)
           mod.extend(ClassMethods) if const_defined?(ClassMethods)

        end
                
    end
    
end