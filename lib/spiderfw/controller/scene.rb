require 'ostruct'

module Spider
    
    class Scene < OpenStruct
                
        def []=(key, val)
            self.send("#{key}=", val)
        end
        
        def [](key)
            #self.send(key)
            @table[key]
        end
        
        def to_json
            @table.to_json
        end
        
        def to_hash
            @table
        end
        
    end
    
    
end
