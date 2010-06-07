module Spider; module Model
    
    # The Mapper connects a BaseModel to a Storage; it fetches data from the Storage and converts it to objects,
    # and vice versa.
    # It is not usually called directly; the BaseModel provides methods for interacting with the mapper.
    # Its methods may be overridden with BaseModel#with_mapper, though.
    
    class Mapper
        attr_reader :model
        attr_accessor :storage
        # Mapper type (:db, :hash, etc.)
        attr_reader :type

        # Returns whether this Mapper can write to the storage.
        def self.write?
            true
        end
        
        # Takes a BaseModel class and a storage instance.
        def initialize(model, storage)
            @model = model
            @storage = storage
            @raw_data = {}
            @options = {}
            @no_map_elements = {}
            @sequences = []
        end
        
        
        # Configuration methods
        
        # Sets that the given elements will not be processed.
        def no_map(*els)
            els.each{ |el| @no_map_elements[el] = true }
        end
        
        # Returns whether the given element can be handled by the mapper.
        def mapped?(element)
            element = element.name if (element.is_a? Element)
            element = @model.elements[element]
            return false if (element.attributes[:unmapped])
            return false if (element.attributes[:computed_from])
            return false if @no_map_elements[element.name]
            return true
        end
        
        def sortable?(element)
            element = element.name if (element.is_a? Element)
            element = @model.elements[element]
            mapped?(element) || element.attributes[:sortable]
        end
        
        # Utility methods
        
        # An array of mapped elements.
        def map_elements # :nodoc:
            @model.elements_array.select{ |el| !@no_map_elements[el.name] }
        end
        
        # Calls the given action. Used by UnitOfWork tasks.
        def execute_action(action, object) # :nodoc:
            case action
            when :save
                save(object)
            when :keys
                # do nothing; keys will be set by save
            else
                raise MapperError, "#{action} action not implemented"
            end
        end
        
        # Converts hashes and arrays to QuerySets and BaseModel instances.
        def normalize(obj)
            obj.no_autoload do
                @model.elements.select{ |n, el| 
                        mapped?(el) &&  el.model? && obj.element_has_value?(el) 
                }.each do |name, element|
                    val = obj.get(name)
                    next if (val.is_a?(BaseModel) || val.is_a?(QuerySet))
                    if (val.is_a? Array)
                        val.each_index { |i| val[i] = Spider::Model.get(element.model, val[i]) unless val[i].is_a?(BaseModel) || val.is_a?(QuerySet) }
                        obj.set(name, QuerySet.new(element.model, val))
                    else
                        val = Spider::Model.get(element.model, val)
                        obj.set(name, val)
                    end
                end
            end
        end
        
        #############################################################
        #   Info                                                    #
        #############################################################
        
        # Returns true if information to find the given element is accessible to the mapper.
        # (see for example DbMapper#have_references?)
        def have_references?(element)
            raise MapperError, "Unimplemented"
        end
        
        # Returns true if information to find the given element is accessible to the mapper, or to an integrated model's mapper.
        # (see for example DbMapper#someone_have_references?)
        def someone_have_references?(element)
            raise MapperError, "Unimplemented"
        end
        
        
        ##############################################################
        #   Save (insert and update)                                 #
        ##############################################################
        
        # This method is called before a save operation, normalizing and preparing the object.
        # 'mode' can be :insert or :update.
        # This method is well suited for being overridden, to add custom preprocessing of the object; just
        # remember to call #super, or use #before_insert and #before_update instead.
        def before_save(obj, mode)
            normalize(obj)
            if (mode == :insert)
                before_insert(obj)
            elsif (mode == :update)
                before_update(obj)
            end
            @model.elements_array.each do |el|
                if (el.attributes[:set_before_save])
                    set_data = el.attributes[:set_before_save]
                    if (el.model? && set_data.is_a?(Hash))
                        if (obj.element_has_value?(el))
                            set_data.each{ |k, v| obj.get(el).set(k, v) }
                        else
                            obj.set(el, el.model.new(set_data))
                        end 
                    else
                        obj.set(el, set_data)
                    end
                end
                if (el.required? && (mode == :insert || obj.element_modified?(el)) && !obj.element_has_value?(el))
                    raise RequiredError.new(el) 
                end
                if (el.unique? && !el.integrated? && obj.element_modified?(el))
                    existent = @model.where(el.name => obj.get(el))
                    if (mode == :insert && existent.length > 0) || (mode == :update && existent.length > 1)
                        raise NotUniqueError.new(el)
                    end
                end
                if mode == :insert && !el.integrated?
                    obj.set(el.name, el.type.auto_value) if el.type < Spider::DataType && el.type.auto?(el)
                    obj.set(el, obj.get(el)) if el.attributes[:default] && !obj.element_modified?(el)
                end
            end
            if (@model.extended_models)
                @model.extended_models.each do |m, el|
                    sub = obj.get(el)
                    if mode == :update || sub.class.auto_primary_keys?
                        sub.save if (obj.element_modified?(el) || !obj.primary_keys_set?) && sub.mapper.class.write?
                    else
                        sub.insert unless sub.in_storage?
                    end
                end
            end
            @model.elements_array.select{ |el| el.attributes[:integrated_model] }.each do |el|
                sub_obj = obj.get(el)
                sub_obj.save if sub_obj && sub_obj.modified? && obj.element_modified?(el) && obj.get(el).mapper.class.write?
            end
        end
        
        # Hook to provide custom preprocessing. The default implementation does nothing.
        def before_insert(obj)
        end
        
        # Hook to provide custom preprocessing. The default implementation does nothing.
        def before_update(obj)
        end
        
        # Hook to provide custom preprocessing. Will be passed a QuerySet. The default implementation does nothing.
        def before_delete(objects)
        end
        
        # Called after a succesful save. 'mode' can be :insert or :update.
        def after_save(obj, mode)
            obj.reset_modified_elements
            save_associations(obj, mode)
            
        end
        
        # Hook called after a succesful save: the object is not in save mode.
        def save_done(obj, mode)
        end
        
        # Hook to provide custom preprocessing. Will be passed a QuerySet. The default implementation does nothing.
        def after_delete(objects)
        end
        
        # Saves the object to the storage.
        def save(obj, request=nil)
            prev_autoload = obj.autoload?
            obj.save_mode
            storage.in_transaction
            if (@model.extended_models && !@model.extended_models.empty?)
                is_insert = false
                # Load local primary keys if they exist
                # FIXME: load without cloning?
                check_obj = obj.clone
                @model.elements_array.select{ |el| el.attributes[:local_pk] }.each do |local_pk|
                    check_obj.get(local_pk)
                end
                @model.elements_array.select{ |el| el.attributes[:local_pk]}.each do |local_pk|
                    if (!check_obj.element_has_value?(local_pk))
                        is_insert = true
                        break
                    end
                end
            end
            save_mode = (!is_insert && obj.primary_keys_set?) ? :update : :insert
            before_save(obj, save_mode)
            # @model.elements_array.select{ |el| el.attributes[:integrated_model] }.each do |el|
            #     obj.get(el).save if obj.element_modified?(el)
            # end
            if (save_mode == :update)
                do_update(obj)
            else
                do_insert(obj)
            end
            after_save(obj, save_mode)
            storage.commit_or_continue
            obj.autoload = prev_autoload
            unless @doing_save_done
                @doing_save_done = true
                save_done(obj, save_mode) 
            end
            @doing_save_done = false
            true
        end

        # Elements that are associated to this one externally.
        def association_elements
             @model.elements_array.select{ |el| 
                 mapped?(el) && !el.integrated? && !have_references?(el) && !(el.attributes[:added_reverse] && el.type == @model)
             }
        end
        
        # Saves object associations.
        def save_associations(obj, mode)
            association_elements.select{ |el| obj.element_has_value?(el) }.each do |el|
                save_element_associations(obj, el, mode)
            end
        end
        
        # Deletes all associations from the given object to the element.
        def delete_element_associations(obj, element, associated=nil)
            if (element.attributes[:junction])
                condition = {element.attributes[:reverse] => obj.primary_keys}
                condition[element.attributes[:junction_their_element]] = associated if associated
                element.mapper.delete(condition)
            else
                if (element.multiple?)
                    condition = Condition.and
                    if (associated)
                        condition = associated.keys_to_condition
                    else
                        condition[element.reverse] = obj
                    end
                    # associated.each do |child|
                    #     condition_row = Condition.or
                    #     element.model.primary_keys.each{ |el| condition_row.set(el.name, '<>', child.get(el))}
                    #     condition << condition_row
                    # end
                    if (element.owned?)
                        element.mapper.delete(condition)
                    else
                        element.mapper.bulk_update({element.reverse => nil}, condition)
                    end
                end
            end
        end
        
        # Saves the associations from the given object to the element.
        def save_element_associations(obj, element, mode)
            our_element = element.attributes[:reverse]
            val = obj.get(element)
            if (element.attributes[:junction])
                their_element = element.attributes[:junction_their_element]
                if (val.model != element.model) # dereferenced junction
                    unless (mode == :insert)
                        current = obj.get_new
                        current_val = current.get(element)
                        condition = Condition.and
                        val_condition = Condition.or
                        current_val.each do |row|
                            next if val.include?(row)
                            val_condition[their_element] = row
                        end
                        condition << val_condition
                        unless condition.empty?
                            condition[our_element] = obj
                            element.model.mapper.delete(condition)
                        end
                    end
                    val.each do |row|
                        next if current_val && current_val.include?(row)
                        junction = element.model.new({ our_element => obj, their_element => row })
                        junction.insert
                    end                    
                else
                    unless mode == :insert
                        condition = Condition.and
                        condition[our_element] = obj
                        if element.attributes[:junction_id]
                            val.each do |row|
                                next unless row_id = row.get(element.attributes[:junction_id])
                                condition.set(:id, '<>', row_id)
                            end
                        end
                        element.model.mapper.delete(condition)
                    end
                    val.set(our_element, obj)
                    if element.attributes[:junction_id]
                        val.save
                    else
                        val.insert
                    end
                end
            else
                if (element.multiple?)
                    condition = Condition.and
                    condition[our_element] = obj
                    val.each do |row|
                        condition_row = Condition.or
                        element.model.primary_keys.each{ |el| condition_row.set(el.name, '<>', row.get(el))}
                        condition << condition_row
                    end
                    if (element.owned?)
                        element.mapper.delete(condition)
                    else
                        element.mapper.bulk_update({our_element => nil}, condition)
                    end
                end
                val.set(our_element, obj)
                val.save
            end
        end
        
        # Saves the given object and all objects reachable from it.
        def save_all(root)
            uow = UnitOfWork.new
            uow.add(root)
            uow.run()
        end
        
        # Inserts the object in the storage.
        def insert(obj)
            prev_autoload = obj.save_mode()
            storage.in_transaction
            before_save(obj, :insert)
            do_insert(obj)
            after_save(obj, :insert)
            storage.commit_or_continue
            obj.autoload = prev_autoload
        end
        
        # Updates the object in the storage.
        def update(obj)
            prev_autoload = obj.save_mode()
            storage.in_transaction
            before_save(obj, :update)
            do_update(obj)
            after_save(obj, :update)
            storage.commit_or_continue
            obj.autoload = prev_autoload
        end
        
        # FIXME: remove?
        def bulk_update(values, conditon) # :nodoc:
        end
        
        # Deletes an object, or objects according to a condition.
        # Will not delete with null condition (i.e. all objects) unless force is true
        def delete(obj_or_condition, force=false)
            
            def prepare_delete_condition(obj)
                condition = Condition.and
                @model.primary_keys.each do |key|
                    condition[key.name] = map_condition_value(key.type, obj.get(key))
                end
                return condition
            end
            
            curr = nil
            if (obj_or_condition.is_a?(BaseModel))
                condition = prepare_delete_condition(obj_or_condition)
                curr = QuerySet.new(@model, obj_or_condition)
            elsif (obj_or_condition.is_a?(QuerySet))
                qs = obj_or_condition
                condition = Condition.or
                qs.each{ |obj| condition << prepare_delete_condition(obj) }
            else
                condition = obj_or_condition.is_a?(Condition) ? obj_or_condition : Condition.new(obj_or_condition)
            end
            Spider::Logger.debug("Deleting with condition:")
            Spider::Logger.debug(condition)
            preprocess_condition(condition)
            cascade = @model.elements_array.select{ |el| !el.integrated? && el.attributes[:delete_cascade] }
            assocs = association_elements.select do |el|
                !storage.supports?(:delete_cascade) || !schema.cascade?(el.name) # TODO: implement
            end
            curr = @model.where(condition) unless curr
            before_delete(curr)
            vals = []
            started_transaction = false
            unless cascade.empty? && assocs.empty?
                storage.in_transaction
                started_transaction = true
                curr.each do |curr_obj|
                    obj_vals = {}
                    cascade.each do |el|
                        obj_vals[el] = curr_obj.get(el)
                    end
                    vals << obj_vals
                    assocs.each do |el|
                        delete_element_associations(curr_obj, el)
                    end
                end
            end
            @model.referenced_by_junctions.each do |junction, element|
                curr.each do |curr_obj|
                    junction_condition = Spider::Model::Condition.new
                    junction_condition[element] = curr_obj
                    junction.mapper.delete(junction_condition)
                end
            end
            do_delete(condition, force)
            vals.each do |obj_vals|
                obj_vals.each do |el, val|
                    el.model.mapper.delete(val)
                end
            end
            after_delete(curr)
            storage.commit_or_continue if started_transaction
        end
        
        # Deletes all objects from the storage.
        def delete_all!
            all = @model.all
            #all.fetch_window = 100
            delete(all, true)
        end
        
        # Actual interaction with the storage. May be implemented by subclasses.
        def do_delete(obj, force=false)
            raise MapperError, "Unimplemented"
        end
        
        # Actual interaction with the storage. May be implemented by subclasses.
        def do_insert(obj)
            raise MapperError, "Unimplemented"
        end
        
        # Actual interaction with the storage. May be implemented by subclasses.
        def do_update(obj)
            raise MapperError, "Unimplemented"
        end
        
        # Actual interaction with the storage. May be implemented by subclasses.
        def lock(obj=nil, mode=:exclusive)
            raise MapperError, "Unimplemented"
        end
        
        # Actual interaction with the storage. May be implemented by subclasses.
        def sequence_next(name)
            raise MapperError, "Unimplemented"
        end
        
        ##############################################################
        #   Load (and find)                                          #
        ##############################################################        
        
        # Loads an element. Other elements may be loaded as well, according to lazy groups.
        def load_element(objects, element)
            load(objects, Query.new(nil, [element.name]))
        end
        
        # Loads only the given element, ignoring lazy groups.
        def load_element!(objects, element)
            load(objects, Query.new(nil, [element.name]), :no_expand_request => true)
        end
        
        # Loads elements of given objects according to query.request.
        def load(objects, query, options={})
            objects = queryset_siblings(objects) unless objects.is_a?(QuerySet)
            request = query.request
            condition = Condition.or
            objects.each_current do |obj|
                condition << obj.keys_to_condition if obj.primary_keys_set?
            end
            return find(Query.new(condition, request), objects, options)
        end
        
        # Finds objects according to a query, merging the results into a query_set if given.
        def find(query, query_set=nil, options={})
            set = nil
            Spider::Model.with_identity_mapper do |im|
#                im.put(query_set)
                # FIXME!!! probably need to update loaded elements, but it's extremely slow
                query_set.update_loaded_elements if query_set
                set = query_set || QuerySet.new(@model)
                was_loaded = set.loaded
                set.loaded = true
                set.index_by(*@model.primary_keys)
                set.last_query = query
                if (query.request.with_superclass? && @model.superclass < BaseModel)
                    return find_with_superclass(query, set, options)
                end
                
                if (@model.attributes[:condition])
                    query.condition = Condition.and(query.condition, @model.attributes[:condition])
                end
                keys_loaded = true
                @model.primary_keys.each do |key|
                    unless set.element_loaded?(key)
                        keys_loaded = false
                        break
                    end
                end
                do_fetch = true
                if (keys_loaded)
                    do_fetch = false
                    query.request.each_key do |key|
                        if (have_references?(key))
                            do_fetch = true
                            break
                        end
                    end
                end
                if (do_fetch)
                    @model.primary_keys.each{ |key| query.request[key] = true}
                    expand_request(query.request, set) unless options[:no_expand_request] || !query.request.expandable?
                    query = prepare_query(query, query_set)
                    query.request.total_rows = true unless query.request.total_rows == false
                    result = fetch(query)
                    if !result || result.empty?
                        set.each_current do |obj|
                            query.request.keys.each do |element_name|
                                el = @model.elements[element_name]
                                next if el.integrated? || @model.extended_models[el.model]
                                obj.set_loaded_value(element_name, nil) 
                            end
                        end
                        return false
                    end
                    set.total_rows = result.total_rows if (!was_loaded)
                    result.each do |row|
                        obj =  map(query.request, row, @model) # set.model ?!?
                        next unless obj
                        merge_object(set, obj)
                        @raw_data[obj.object_id] = row
                    end
                end
                set = get_external(set, query)
#                delay_put = true if (@model.primary_keys.select{ |k| @model.elements[k.name].integrated? }.length > 0)

               
                # if (delay_put)
                #     set.no_autoload(false) do
                #         set.each_index do |i|
                #             set[i].primary_keys_set?
                #             set[i] = im.put(set[i], true)
                #         end
                #     end
                # end
            end
            return set
        end
        
        
        def merge_object(set, obj) # :nodoc:
            search = {} 
            @model.primary_keys.each{ |k| search[k.name] = obj.get(k.name) }
            obj_res = set.find(search)  # FIXME: find a better way
            if (obj_res && obj_res[0])
                obj_res[0].merge!(obj)
                obj.loaded_elements.each{ |name, bool| set.element_loaded(name) }
            else
                set << obj
            end
        end
        
        def find_with_superclass(query, set=nil, options={}) # :nodoc:
            q = query.clone
            polym_request = Request.new
            polym_condition = Condition.new
            query.request.keys.each do |el_name|
                if (!@model.superclass.has_element?(el_name))
                    polym_request[el_name] = true
                    query.request.delete(el_name)
                end
            end
            q.with_polymorph(@model, polym_request)
            res = @model.superclass.mapper.find(q)
            res.change_model(@model)
            res.each do |obj|
                merge_object(set, obj)
            end
            return set
        end
        
        # Does a count query on the storage for given condition
        def count(condition)
            query = Query.new(condition)
            result = fetch(query)
            return result.length
        end
        
        # Actual interaction with the storage. Should be implemented by subclasses.
        def fetch(query)
            raise MapperError, "Unimplemented"
        end
        
        
        # Transforms a Storage result into an object. Should be implemented by subclasses.
        def map(request, result, obj)
            raise MapperError, "Unimplemented"
        end
        
        # Loads external elements, according to query,  and merges them into an object or a QuerySet
        def get_external(objects, query)
            objects = queryset_siblings(objects) unless objects.is_a?(QuerySet)
            return objects if objects.length < 1
            got_external = {}
            get_integrated = {}
            query.request.each_key do |element_name|
                element = @model.elements[element_name]
                next unless element && (mapped?(element) || element.attributes[:element_query])
                next if objects.element_loaded?(element_name)
                next unless element.reverse # FIXME
                if element.integrated?
                   get_integrated[element.integrated_from] ||= Request.new
                   get_integrated[element.integrated_from][element.integrated_from_element] = query.request[element_name]
                elsif element.model?
                    next if query.request[element_name] == true && someone_have_references?(element)
                    sub_query = Query.new
                    sub_query.request = ( query.request[element_name].class == Request ) ? query.request[element_name] : nil
                    sub_query.condition = element.attributes[:condition] if element.attributes[:condition]
                    got_external[element] = true
                    objects = get_external_element(element, sub_query, objects)
                end
                # no furter attempts to try; set as loaded
                objects.element_loaded(element_name)
            end
            get_integrated.each do |integrated, request|
                next if got_external[integrated]
                next if objects.element_loaded?(integrated.name)
                sub_query = Query.new(nil, request)
                objects = get_external_element(integrated, sub_query, objects)
                objects.element_loaded(integrated)
            end
            return objects
        end
        
        # Loads an external element, according to query, and merges the result into an object or QuerySet.
        def get_external_element(element, query, objects)
            Spider::Logger.debug("Getting external element #{element.name} for #{@model}")
            return load_element(objects, element) if (have_references?(element))
            return nil if objects.empty?
            index_by = []
            @model.primary_keys.each{ |key| index_by << :"#{element.attributes[:reverse]}.#{key.name}" }
            result = objects.element_queryset(element).index_by(*index_by)
            @model.primary_keys.each{ |key| result.request[key.name] = true }
            result.request[element.attributes[:reverse]] = true
            if element.attributes[:polymorph]
                element.type.polymorphic_models.each do |mod, params|
                    poly_req = Spider::Model::Request.new
                    mod.primary_keys.each{ |k| poly_req.request(k) }
                    result.request.with_polymorphs(mod, poly_req)
                end
            end
            result.load
            return associate_external(element, objects, result)
        end
        
        # Given the results of a query for an element, and a set of objects, associates
        # the result with the corresponding objects.
        def associate_external(element, objects, result)
#            result.reindex
            objects.element_loaded(element.name)
            objects.each_current do |obj|
                search_params = {}
                @model.primary_keys.each do |key|
                    field = @schema.field(key.name)
                    search_params[:"#{element.attributes[:reverse]}.#{key.name}"] = obj.get(key)
                end
                sub_res = result.find(search_params)
                sub_res.each do |sub_obj|
                    sub_obj.set_loaded_value(element.attributes[:reverse], obj)
                end
                sub_res = sub_res[0] if !element.multiple?
                sub_res.loadable = false if sub_res.respond_to?(:loadable=)
                obj.set_loaded_value(element, sub_res)
            end
            return objects
        end
        
        # Returns the siblings, if any, of the object, in its ancestor QuerySet.
        def queryset_siblings(obj)
            return QuerySet.new(@model, obj) unless obj._parent
            orig_obj = obj
            path = []
            seen = {obj => true}
            while (obj._parent && !seen[obj._parent])
                path.unshift(obj._parent_element) if (obj._parent_element) # otherwise it's a query set
                obj = obj._parent
                seen[obj] = true
            end
            res = path.empty? ? obj : obj.all_children(path)
            raise RuntimeError, "Broken object path" if (obj && !path.empty? &&  res.length < 1)
            res = QuerySet.new(@model, res) unless res.is_a?(QuerySet)
            return res
        end
        

        # Converts a value from the storage to a value for the object.
        def map_back_value(type, value)
            raise MapperError, "Unimplemented"
        end
        
        
        ##############################################################
        #   Strategy                                                 #
        ##############################################################

        def prepare_query(query, obj=nil)
            if (query.request.polymorphs?)
                conds = split_condition_polymorphs(query.condition, query.request.polymorphs.keys) 
                conds.each{ |polym, c| query.condition << c }
            end
            @model.elements_array.select{ |el| el.attributes[:order] }.sort{ |a, b| 
                a_order = a.attributes[:order]; b_order = b.attributes[:order]
                (a_order.is_a?(Fixnum) ? a_order : 100) <=> (b_order.is_a?(Fixnum) ? b_order : 100)
            }.each{ |order_el| query.order_by(order_el.name) }
            query = @model.prepare_query(query)
            prepare_query_request(query.request, obj)
            preprocess_condition(query.condition)
            return query
        end
        
        def split_condition_polymorphs(condition, polymorphs)
            conditions = {}
            return conditions if condition.polymorph && polymorphs.include?(condition.polymorph)
            model = condition.polymorph ? condition.polymorph : @model
            condition.each_with_comparison do |el, val, comp|
                if (!model.has_element?(el))
                    polymorphs.each do |polym|
                        if (polym.has_element?(el))
                            conditions[polym] ||= Condition.new
                            conditions[polym].polymorph = polym
                            conditions[polym].set(el, comp, val)
                            condition.delete(el)
                        end
                    end
                end
            end
            condition.subconditions.each do |sub|
                res = split_condition_polymorphs(sub, polymorphs)
                polymorphs.each do |polym|
                    next unless res[polym]
                    if (!conditions[polym])
                        conditions[polym] = res[polym]
                    else
                        conditions[polym] << res[polym]
                    end
                end
            end
            return conditions
        end
        
        
        # Normalizes a request.
        def prepare_query_request(request, obj=nil)
            @model.primary_keys.each do |key|
                request[key] = true
            end
            request.each do |k, v|
                next unless element = @model.elements[k]
                if (element.integrated?)
                    integrated_from = element.integrated_from
                    integrated_from_element = element.integrated_from_element
                    request.request("#{integrated_from.name}.#{integrated_from_element}")
                end
            end
        end
        
        # Adds lazy groups to request.
        def expand_request(request, obj=nil)
            lazy_groups = []
            request.each do |k, v|
                unless element = @model.elements[k]
                    request.delete(k)
                    next
                end
                grps = element.lazy_groups
                lazy_groups += grps if grps
            end
            lazy_groups.uniq!
            @model.elements.each do |name, element|
                next if (obj && obj.element_loaded?(name))
                if (element.lazy_groups && (lazy_groups - element.lazy_groups).length < lazy_groups.length)
                    if (element.attributes[:lazy_check_owner])
                        next unless have_references?(name)
                    end
                    request.request(name)
                end
            end
        end
        
        # Preprocessing of the condition
        def preprocess_condition(condition)
            model = condition.polymorph ? condition.polymorph : @model
            condition.simplify
            
            # This handles integrated elements, junctions, and prepares types
            def basic_preprocess(condition) # :nodoc:
                condition.each_with_comparison do |k, v, c|
                    next if k.is_a?(Spider::QueryFuncs::Function)
                    next unless element = model.elements[k]
                    if (element.integrated?)
                        condition.delete(k)
                        integrated_from = element.integrated_from
                        integrated_from_element = element.integrated_from_element
                        condition.set("#{integrated_from.name}.#{integrated_from_element}", c, v)
                    elsif (element.junction? && !v.is_a?(BaseModel) && !v.is_a?(Hash) && !v.nil?) # conditions on junction id don't make sense
                        condition.delete(k)
                        condition.set("#{k}.#{element.attributes[:junction_their_element]}", c, v)
                    end
                    if (element.type < Spider::DataType && !v.is_a?(element.type))
                        condition.delete(k)
                        begin
                            condition.set(k, c, element.type.from_value(v))
                        rescue TypeError => exc
                            raise TypeError, "Can't convert #{v} to #{element.type} for element #{k} (#{exc.message})"
                        end
                    elsif element.type == DateTime && v && !v.is_a?(Date)
                        condition.delete(k)
                        condition.set(k, c, DateTime.parse(v))
                    end
                end
            end
            
            basic_preprocess(condition)
            if @model.respond_to?(:prepare_condition)
                condition = @model.prepare_condition(condition)
                basic_preprocess(condition)
            end
            
            # Utility function to set conditions on 
            def set_pks_condition(condition, el, val, prefix) # :nodoc:
                el.model.primary_keys.each do |primary_key|
                    new_prefix = "#{prefix}.#{primary_key.name}"
                    if (primary_key.model?)
                        if (primary_key.model.primary_keys.length == 1)
                            # FIXME: this should not be needed, see below
                            condition.set(new_prefix, '=', val.get(primary_key).get(primary_key.model.primary_keys[0]))
                        else
                            # FIXME! does not work, the subcondition does not get processed
                            raise "Subconditions on multiple key elements not supported yet"
                            subcond = Condition.new
                            set_pks_condition(subcond,  primary_key, val.get(primary_key), new_prefix)
                            condition << subcond
                        end
                    else
                        condition.set(new_prefix, '=', val.get(primary_key))
                    end
                end
            end
            
            # normalize condition values; converts objects and primary key values to correct conditions on keys
            condition.each_with_comparison do |k, v, comp|
                next if k.is_a?(QueryFuncs::Function)
                element = model.elements[k.to_sym]
                if (v && !v.is_a?(Condition) && element.model?)
                    condition.delete(element.name)
                    if v.is_a?(BaseModel)
                        set_pks_condition(condition, element, v, element.name)
                    elsif element.model.primary_keys.length == 1 
                        new_v = Condition.new
                        if (model.mapper.have_references?(element.name))
                            new_v.set(element.model.primary_keys[0].name, comp, v)
                        else
                            new_v.set(element.reverse, comp, v)
                        end
                        condition.set(element.name, comp, new_v)
                    else
                        raise MapperError, "Value condition passed on #{k}, but #{element.model} has more then one primary key"
                    end
                end
            end
            
            # Final sanity check
            condition.each_with_comparison do |k, v, comp|
                next if k.is_a?(QueryFuncs::Function)
                element = model.elements[k.to_sym]
                raise MapperError , "Condition for non-existent element #{model}.#{k} " unless element
                raise MapperError, "Condition for computed element #{model}.#{k}" if element.attributes[:computed_from]
            end
            
            # Process subconditions
            condition.subconditions.each do |sub|
                preprocess_condition(sub)
            end
            return condition
        end
        
        # Returns task dependecies for the UnitOfWork. May be implemented by subclasses.
        def get_dependencies(obj, action)
            return []
        end
        
        
    end
    
    ##############################################################
    #   MapperTask                                               #
    ##############################################################
    
    # The MapperTask is used by the UnitOfWork.
    class MapperTask
        attr_reader :dependencies, :object, :action
       
        def initialize(object, action)
            @object = object
            @action = action
            @dependencies = []
        end
        
        def <<(task)
            @dependencies << task
        end
        
        def execute()
            Spider::Logger.debug "Executing #{@action} on #{@object}"
            @object.mapper.execute_action(@action, @object)
        end
        
        def eql?(task)
            return false unless task.class == self.class
            return false unless (task.object == self.object && task.action == self.action)
            return true
        end
        
        def hash
            return @object.hash + @action.hash
        end
        
        def ===(task)
            return eql?(task)
        end
        
        # def to_s
        #     "#{@action} on #{@object} (#{object.class})\n"
        # end
        
        def inspect
            if (@action && @object)
                str = "#{@action} on #{@object} (#{object.class})\n"
                if (@dependencies.length > 0)
                    str += "-dependencies:\n"
                    @dependencies.each do |dep|
                        str += "---#{dep.action} on #{dep.object}\n"
                    end
                end
            else
                str = "Root Task"
            end
            return str
        end
        
    end
    
    ##############################################################
    #   Aggregates                                               #
    ##############################################################
    
    def max(element, condition=nil)
        raise "Unimplemented"
    end
    
    
    ##############################################################
    #   Exceptions                                               #
    ##############################################################
    
    # Generic Mapper error.
    
    class MapperError < RuntimeError; end
    
    # Generic Mapper error regarding an element.
    
    class MapperElementError < MapperError
        def initialize(element)
            @element = element
        end
        def element
            @element
        end
        def self.create_subclass(msg)
            e = Class.new(self)
            e.msg = msg
            return e
        end
        def self.msg=(msg)
            @msg = msg
        end
        def self.msg
            @msg
        end
        def message
            _(self.class.msg) % @element.label
        end
        def to_s
            self.class.name.to_s + " " + message
        end
    end
    
    # A required element has no value
    
    RequiredError = MapperElementError.create_subclass(_("Element %s is required"))
    
    # An uniqueness constraint has been violated.
    
    NotUniqueError = MapperElementError.create_subclass(_("Another item with the same %s is already present"))

        
    
end; end
