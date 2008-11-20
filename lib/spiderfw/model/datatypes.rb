module Spider
    
    module DataTypes
        
        class DataType
            @maps_to = 'text'
            
            def initialize(val=nil)
                set(val) if val
            end
            
            def self.maps_to(val=nil)
                if (val)
                    @maps_to = val
                else
                    @maps_to
                end
            end
            
            def set(val)
                @val = val
            end
            
            def serialize(val)
                val
            end
            
            def unserialize(val)
                val
            end
                
        end
        
        autoload(:Bool, 'spiderfw/model/datatypes/bool')
        autoload(:Text, 'spiderfw/model/datatypes/text')
        
        
    end
    
end