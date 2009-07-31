require 'yaml'

module Spider; module DataTypes
    
    class DumpedObject
        include DataType
        maps_to :string
        
        def self.from_value(val)
            val.extend(DumpedObjectMixin)
        end
        
    end
    
    module DumpedObjectMixin
        include DataType
        
        def map(mapper_type)
            YAML::dump(self)
        end
        
        def map_back(mapper_type, val)
            YAML::load(val).extend(DumpedObjectMixin)
        end
        
    end
    
    
end; end