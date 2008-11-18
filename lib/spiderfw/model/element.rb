require 'spiderfw/model/type'

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
        
        def queryset
            return nil unless model?
            set = QuerySet.new(type)
            set.query.condition = @attributes[:condition] if @attributes[:condition]
            if (@attributes[:request])
                set.query.request = @attributes[:request]
            else
                type.elements.each do |name, el|
                    set.query.request[name] = true unless el.model?
                end
            end
            return set
        end
        
        # Clones the current model, detaching it from the original class and allowing to modify
        # it (adding other elements)
        def clone_model
            return if @cloned_model
            @type = @type.clone
            @cloned_model = true
        end

    end

end; end