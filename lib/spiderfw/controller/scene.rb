require 'ostruct'

module Spider
    
    class Scene < OpenStruct
                
        def []=(key, val)
            self.send("#{key}=", val)
        end
        
        def [](key)
            self.send(key)
        end
                
    end
    
    
end