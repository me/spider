module Spider; module Model
    
    class IntegratedElement < Element
        attr_accessor :owner
        
        def initialize(name, owner, integrated_element, integrated_element_element, attributes={})
            @name = name
            @owner = owner
            el = @owner.elements[integrated_element]
            @definer_model = el.model.elements[integrated_element_element].definer_model
            @integrated_element = integrated_element
            @integrated_element_element = integrated_element_element
            @attributes = ({
                :integrated => true,
                :integrated_from => el,
                :integrated_from_element => @integrated_element_element
            }).merge(attributes)
        end
        
        def integrated?
            true
        end
        
        def target_element
            @target_element ||= @owner.elements[@integrated_element].type.elements[@integrated_element_element]
        end
        
        def type
            target_element.type
        end
        
        def attributes
            target_element.attributes.merge(@attributes)
        end
        
        
        def clone
            self.class.new(@name, @owner, @integrated_element, @integrated_element_element, @attributes.clone)
        end
        
    end
    
end; end