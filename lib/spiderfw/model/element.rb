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
            @attributes[:multiple] ? true : false
        end
        
        def required?
            @attributes[:required] ? true : false
        end
        
        def model?
            return true if type.class == Class && type.subclass_of?(Spider::Model::BaseModel)
        end
        
        def integrated?
            @attributes[:integrated_from] ? true : false
        end
        
        def integrated_from
            @attributes[:integrated_from]
        end
        
        def integrated_from_element
            @attributes[:integrated_from_element]
        end
        
        def custom_type?
            return true if type.class.subclass_of?(Spider::Model::Type)
        end
        
        def primary_key?
            @attributes[:primary_key] ? true : false
        end
        
        def read_only?
            @attributes[:read_only] ? true : false
        end
        
        def has_single_reverse?
            return true if @attributes[:reverse] && !model.elements[@attributes[:reverse]].multiple?
        end
        
        def added?
            @attributes[:added] ? true : false
        end
        
        def inline?
            @attributes[:inline] ? true : false
        end
        
        def extended?
            @attributes[:extended] ? true : false
        end
        
        def method?
            @attributes[:method] ? true : false
        end
        
        def hidden?
            @attributes[:hidden] ? true : false
        end
        
        def label
            return @attributes[:label] || Inflector.underscore_to_upcasefirst(@name.to_s)
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
            set_model = @attributes[:queryset_model] ? @attributes[:queryset_model] : type
            set = QuerySet.new(set_model)
            set.query.condition = @attributes[:condition] if @attributes[:condition]
            if (@attributes[:request])
                set.query.request = @attributes[:request]
            else
                set_model.elements.each do |name, el|
                    set.query.request[name] = true unless el.model?
                end
            end
            return set
        end
        
        # Clones the current model, detaching it from the original class and allowing to modify
        # it (adding other elements)
        def extend_model
            return if @extended_model
            orig_type = @type
            class_name = @type.name
            @type = Class.new(BaseModel)
            @type.extend_model(orig_type)
            @type.instance_variable_set(:"@name", orig_type.name+'.'+@name.to_s)
            @type.instance_eval do
                def name
                    @name
                end
                
                @proxied_type = orig_type
                # def storage
                #     # it has only added elements, they will be merged in by the element owner
                #     require 'spiderfw/model/storage/null_storage'
                #     return Spider::Model::Storage::NullStorage.new
                # end
                def mapper
                    require 'spiderfw/model/mappers/proxy_mapper'
                    return @mapper ||= Spider::Model::Mappers::ProxyMapper.new(self, @proxied_type)
                end
            end
            @extended_model = true
        end

    end

end; end