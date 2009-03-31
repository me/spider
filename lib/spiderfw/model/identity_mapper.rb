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
        
        def get(model, values)
            # Spider::Logger.debug("IM GETTING #{model}")
            # Spider::Logger.debug("IM GETTING #{values}")
            @objects[model] ||= {}
            pks = {}
            model.primary_keys.each do |k| 
                # dereference integrated primary keys
                pks[k.name] = (k.integrated? && values[k.integrated_from.name]) ? 
                    values[k.integrated_from.name].get(k.integrated_from_element) :
                    values[k.name]
                raise IdentityMapperException, "Can't get without all primary keys" unless pks[k.name]
            end
            pks.extend(HashComparison)
            obj = (@objects[model][pks] ||= model.new(pks))
            pks.each{ |k, v| obj.element_loaded(k) }
            values.reject{|k,v| model.elements[k].primary_key? }.each do |k, v|
                obj.set_loaded_value(k, v)
            end
#            Spider::Logger.debug("RETURNING #{obj.class} #{obj.object_id}")
            return obj
        end
        
        def put(obj, check=false)
            return nil unless obj
            if (obj.is_a?(QuerySet))
                obj.no_autoload(false) do
                    obj.each_index{ |i| obj[i] = put(obj[i], check) }
                end
                return obj
            else
                raise IdentityMapperException, "Can't get without all primary keys" unless obj.primary_keys_set?
                pks = {}
                obj.class.primary_keys.each{ |key| pks[key.name] = obj.get(key) }
                @objects[obj.class] ||= {}
                if (check && (existent = @objects[obj.class][pks]) && existent.object_id != obj.object_id)
                    existent.merge!(obj)
                    return existent
                else
                    return @objects[obj.class][pks] = obj
                end
            end
        end

        
        module HashComparison
            def eql?(h)
                self == h
            end
            def hash
                self.to_a.hash
            end
        end
        
    end
    
    class IdentityMapperException < RuntimeError
    end
    
    
end; end 