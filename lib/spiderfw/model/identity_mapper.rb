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
            @pks = {}
            if (proc)
                prev_im = Spider::Model.identity_mapper
                Spider::Model.identity_mapper = self
                begin
                    yield self
                ensure
                    Spider::Model.identity_mapper = prev_im
                end
            end
        end
        
        # Get an instance of model with given values. Values must contain all of model's primary keys.
        # If an object with the same primary keys is found, it will be used; otherwise, a new instance will be
        # created.
        # In any case, the given values will be set on the object, before it is returned.
        #---
        # FIXME: refactor avoiding set_loaded
        def get(model, values=nil, set_loaded=false)
            
            if !values && model.is_a?(BaseModel)
                curr = has?(model)
                return curr ? curr : put(model)
            end
            
            @objects[model] ||= {}
            pks = {}
            has_pks = false
            model.primary_keys.each do |k| 
                # dereference integrated primary keys
                v = (k.integrated? && values[k.integrated_from.name]) ? 
                    values[k.integrated_from.name].get(k.integrated_from_element) :
                    values[k.name]
                has_pks = true if v
                pks[k.name] = model.prepare_value(k, v)
            end
            orig_pks = pks.clone
            normalize_pks(model, pks)
            unless has_pks
                raise IdentityMapperException, "Can't get #{model} from IdentityMapper without all primary keys, #{values.inspect} given"
            end
            pks.extend(HashComparison)
            current = @objects[model][pks]
            obj = nil
            if current
                obj = current
            else
#                Spider.logger.debug("GETTING NEW #{model} FROM #{pks.inspect}")
                obj = model.new(orig_pks)
                #@objects[model][pks] = obj
            end
            # obj = (@objects[model][pks] ||= model.new(pks))
            pks.each{ |k, v| obj.element_loaded(k) }
            values.reject{|k,v| model.elements[k].primary_key? }.each do |k, v|
                v = get(v) if v.is_a?(BaseModel)
                if set_loaded
                    obj.set_loaded_value(k, v)
                else
                    obj.set(k, v)
                end
            end
#            Spider::Logger.debug("RETURNING #{obj.class} #{obj.object_id}")
            return obj
        end
        
        # Puts an object into the identity mapper.
        # If check is true, it will first check if the object exists, and if found merge it with the given obj;
        # if check is false, if a object with the same primary keys exists it will be overwritten.
        def put(obj, check=false, fail_if_exists=false)
            return nil unless obj
            return obj if obj._no_identity_mapper
            if (obj.is_a?(QuerySet))
                obj.each_current_index{ |i| obj[i] = put(obj[i], check) }
                return obj
            else
                return obj if @pks[obj.object_id]
                raise IdentityMapperException, "Can't get without all primary keys" unless obj.primary_keys_set?
                pks = {}
                obj.class.primary_keys.each{ |key| pks[key.name] = obj.get(key) }
                pks = normalize_pks(obj.class, pks)
                pks.extend(HashComparison)
                @objects[obj.class] ||= {}
                if (check && (existent = @objects[obj.class][pks]) && existent.object_id != obj.object_id)
                    if fail_if_exists
                        #debugger
                        raise IdentityMapperException, "A different instance of the same object #{obj.class}(#{obj.primary_keys.inspect}) already exists in the identity mapper" 
                    end
                    existent.merge!(obj)
                    return existent
                else
                    @objects[obj.class][pks] = obj
                    @pks[obj.object_id] = pks
                    traverse(obj)
                    uow = Spider::Model.unit_of_work
                    uow.add(obj) if uow && !uow.running?
                    return obj
                end
            end
        end
        
        def traverse(obj, check=false, fail_if_exists=false)
            obj.class.elements_array.each do |el|
                next unless obj.element_has_value?(el)
                next unless el.model?
                subs = obj.get(el)
                subs = [subs] unless subs.is_a?(Enumerable)
                subs.each do |sub|
                    put(sub, check, fail_if_exists) if sub && sub.primary_keys_set? && has?(sub).object_id != sub.object_id
                end
            end
            
        end
        
        def put!(obj)
            put(obj, true, true)
        end
        
        
        def has?(obj)
            pks = {}
            obj.class.primary_keys.each{ |key| pks[key.name] = obj.get(key) }
            pks = normalize_pks(obj.class, pks)
            pks.extend(HashComparison)
            @objects[obj.class] && @objects[obj.class][pks]
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
        
        def normalize_pks(model, keys)
            model_pks = model.primary_keys.map{ |k| k.name }
            model_pks.each do |k|
                if keys[k] && keys[k].is_a?(BaseModel)
                    keys[k] = keys[k].class.primary_keys.length > 1 ? keys[k].primary_keys : keys[k].primary_keys[0]
                    keys[k] = keys[k].first if model.elements[k].type.primary_keys.length && keys[k].is_a?(Array)
                end
            end
            keys.keys.each do |k|
                keys.delete(k) unless model_pks.include?(k)
            end
            keys
        end

        
    end
    
    class IdentityMapperException < RuntimeError
    end
    
    
end; end 