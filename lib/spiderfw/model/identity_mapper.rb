require 'spiderfw/utils/hash_comparison'

module Spider; module Model
    
    # The IdentityMapper, when in use, will hold a reference to each object; the mapper will coordinate
    # with it to ensure that each object of the same model with the same primary keys will point to the same
    # Ruby object.
    # This may or may not be what you need: the IdentityMapper can be set globally by assigning an instance
    # to #Spider::Model.identity_mapper=, or for a block of code by passing a block to the initializer.
    class IdentityMapper
        
        # If passed a block, will activate the IdentityMapper, yield, and then deactivate it.
        def initialize(&proc)
            @objects = {}
            if (proc)
                Thread.current[:identity_mapper] = self
                yield self
                Thread.current[:identity_mapper] = nil
            end
        end
        
        # Get an instance of model with given values. Values must contain all of model's primary keys.
        # If an object with the same primary keys is found, it will be used; otherwise, a new instance will be
        # created.
        # In any case, the given values will be set on the object, before it is returned.
        def get(model, values)
            @objects[model] ||= {}
            pks = {}
            has_pks = false
            model.primary_keys.each do |k| 
                # dereference integrated primary keys
                pks[k.name] = (k.integrated? && values[k.integrated_from.name]) ? 
                    values[k.integrated_from.name].get(k.integrated_from_element) :
                    values[k.name]
                has_pks = true if pks[k.name]
            end
            raise IdentityMapperException, "Can't get without all primary keys" unless has_pks
            pks.extend(HashComparison)
            obj = (@objects[model][pks] ||= model.new(pks))
            pks.each{ |k, v| obj.element_loaded(k) }
            values.reject{|k,v| model.elements[k].primary_key? }.each do |k, v|
                obj.set_loaded_value(k, v)
            end
#            Spider::Logger.debug("RETURNING #{obj.class} #{obj.object_id}")
            return obj
        end
        
        # Puts an object into the identity mapper.
        # If check is true, it will first check if the object exists, and if found merge it with the given obj;
        # if check is false, if a object with the same primary keys exists it will be overwritten.
        def put(obj, check=false)
            return nil unless obj
            if (obj.is_a?(QuerySet))
                obj.each_current_index{ |i| obj[i] = put(obj[i], check) }
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
                    @objects[obj.class][pks] = obj
                    @pks[obj.object_id] = pks
                    return obj
                end
            end
        end
        
        def delete(klass, obj_id)
            pks = @pks[obj_id]
            return unless pks && @objects[klass]
            @objects[klass].delete(pks)
            @pks.delete(obj_id)
        end
        
        def reset
            @objects = {}
            @pks = {}
        end

        
    end
    
    class IdentityMapperException < RuntimeError
    end
    
    
end; end 