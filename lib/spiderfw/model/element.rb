require 'spider/model/type'

module Spider; module Model

    class Element
        attr_reader :name, :attributes

        def initialize(name, type, attributes={})
            @name = name
            @type = type
            @attributes = attributes
        end
        
        def type
            @type = const_get_recursive(@type) if @type.class == Symbol
            return @type
        end
        
        def model
            return nil unless model?
            return type
        end
        
        def multiple?
            return true if @attributes[:multiple]
        end
        
        def model?
            return true if type.class == Class && type.subclass_of?(Spider::Model::BaseModel)
        end
        
        def custom_type?
            return true if type.class.subclass_of?(Spider::Model::Type)
        end
        
        def primary_key?
            return true if @attributes[:primary_key]
        end
        
        def has_single_reverse?
            return true if @attributes[:reverse] && !model.elements[@attributes[:reverse]].multiple?
        end
        
        def added?
            return true if @attributes[:added]
        end
        
        def to_s
            return "Element '#{@name.to_s}'"
        end
        
        def storage
            return nil unless model?
            return model.storage
        end
        
        def mapper
            return nil unless model?
            return model.mapper
        end
        
        # Clones the current model, detaching it from the original class and allowing to modify
        # it (adding other elements)
        def clone_model
            return if @cloned_model
            @cloned_model = @type
            @type = @type.clone
            @type.instance_variable_set(:"@name", @cloned_model.name)
            @type.class_eval do
                @elements = @elements.clone if @elements
            end
            @type.instance_eval do
                def name
                    return @name
                end
            end
            @type.instance_variable_set(:@name, @type.name)
            def @type.add_element(name, type, attributes={})
                el = self.element(name, type, attributes)
                el.attributes[:added] = true
                @elements[name] = el
                @added_elements ||= []; @added_elements << el
            end
        end

    end

end; end