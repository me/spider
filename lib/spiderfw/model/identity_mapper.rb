module Spider; module Model
    
    class IdentityMapper
        
        def initialize(&proc)
            @objects = {}
            if (proc)
                Thread.current[:identity_mapper] = self
                yield self
                Thread.current[:identity_mapper] = nil
            end
        end
        
        def get(model, keys)

            @objects[model] ||= {}
            model.primary_keys.each do |k| 
                raise IdentityMapperException, "Can't get without all primary keys" unless keys[k.name]
            end
            pks = keys.reject{|k,v| !model.elements[k].primary_key?}
            obj = (@objects[model][pks] ||= model.new(keys))
            keys.reject{|k,v| model.elements[k].primary_key? }.each do
                obj.set(k, v)
            end
            return obj
        end
        
        def put(obj, check=false)
            return nil unless obj
            if (obj.is_a?(QuerySet))
                obj.each_index{ |i| obj[i] = put(obj[i], check) }
                return obj
            else
                raise IdentityMapperException, "Can't get without all primary keys" unless obj.primary_keys_set?
                pks = {}
                obj.class.primary_keys.each{ |key| pks[key.name] = obj.get(key) }
                @objects[obj.class] ||= {}
                if (check && existent = @objects[obj.class][pks])
                    obj.no_autoload do
                        obj.class.elements_array.select{ |el| obj.element_has_value?(el) }.each do |el|
                            existent.set_loaded_value(el, obj.get(el)) 
                        end
                    end
                    return existent
                else
                    return @objects[obj.class][pks] = obj
                end
            end
        end
        
    end
    
    class IdentityMapperException < RuntimeError
    end
    
    
end; end 