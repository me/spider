require 'yaml'

module Spider; module DataTypes
    
    class SerializedObject
        include DataType
        maps_to Text
        
        def self.from_value(val)
            if (val.is_a?(String))
                val = YAML::load(val)
            end
            val.extend(SerializedMixin)
        end
        
    end
    
    module SerializedMixin
        include DataType
        
        def map(mapper_type)
            YAML::dump(self)
        end
        
        def map_back(mapper_type, val)
            YAML::load(val).extend(SerializedMixin)
        end
        
    end
    
    
end; end