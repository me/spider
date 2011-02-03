module Spider; module Model
    
    module Junction
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        module ClassMethods
            
            def has_added_elements?
                junction_added_elements.length > 0
            end
            
            def junction_added_elements
                self.elements_array.select{ |el| !el.integrated? && !el.attributes[:junction_id] && !el.attributes[:junction_reference] }
            end
            
        end
        
    end
    
end; end