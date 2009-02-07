module Spider

    class DataType
        @maps_to = nil
    
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
    
        def self.take_attributes(*list)
            if (list)
                @take_attributes = list
            else
                @take_attributes || []
            end
        end
    
        def attributes
            @attributes ||= {}
        end
            
    
        def set(val)
            @val = val
        end
        
        def get
            return @val
        end
        
        def inspect
            @val
        end
        
        def map(mapper_type)
            @val
        end
        
        def map_back(mapper_type, val)
        end
    
        # def serialize(val)
        #     val
        # end
        #     
        # def unserialize(val)
        #     val
        # end
        
    end
    
end