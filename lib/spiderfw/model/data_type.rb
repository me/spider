module Spider

    module DataType
        @maps_to = nil
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        module ClassMethods
            
            def from_value(value)
                return nil if value.nil?
                return self.new(value)
            end
    
            def maps_to(val=nil)
                @maps_to = val if val
                @maps_to
            end
            
            def maps_back_to(val=nil)
                @maps_back_to = val if val
                @maps_back_to
            end
    
            def take_attributes(*list)
                if (list)
                    @take_attributes = list
                else
                    @take_attributes || []
                end
            end
            
        end
    
        def attributes
            @attributes ||= {}
        end
        
        def map(mapper_type)
            @val
        end
        
        def map_back(mapper_type, val)
            @val
        end
        
        def format(format)
            self.to_s
        end
        
    end
    
end