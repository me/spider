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
        
        def <<(other)
            if other.is_a?(Hash)
                @table.merge!(other)
            end
        end
        
        def merge!(other)
            @table.merge!(other.instance_variable_get("@table"))
            self
        end
        
    end
    
    
end
