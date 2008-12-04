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
            pks = keys.reject{|k,v| !model.elements[k].primary_key?}
            obj = (@objects[model][pks] ||= model.new(keys))
            keys.reject{|k,v| model.elements[k].primary_key? }.each do
                obj.set(k, v)
            end
            return obj
        end
        
        def put(obj)
            return unless obj
            if (obj.is_a?(QuerySet))
                obj.each{ |sub| put(sub) }
            else
                pks = {}
                obj.class.primary_keys.each{ |key| pks[key.name] = obj.get(key) }
                @objects[obj.class] ||= {}
                @objects[obj.class][pks] = obj
            end
        end
        
    end
    
    
end; end 