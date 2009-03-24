module Spider; module Model
    
    class Mapper
        attr_accessor :storage
        attr_reader :type

        
        def initialize(model, storage)
            @model = model
            @storage = storage
            @raw_data = {}
            @options = {}
            @no_map_elements = {}
            @sequences = []
        end
        
        
        # Configuration methods
        
        def no_map(*els)
            els.each{ |el| @no_map_elements[el] = true }
        end
        
        def mapped?(element)
            element = element.name if (element.is_a? Element)
            element = @model.elements[element]
            return false if (element.attributes[:unmapped])
            return false if (element.attributes[:computed_from])
            return false if @no_map_elements[element.name]
            return true
        end
        
        # Utility methods
        
        def map_elements
            @model.elements_array.select{ |el| !@no_map_elements[el.name] }
        end
        
        def execute_action(action, object)
            case action
            when :save
                save(object)
            when :keys
                # do nothing; keys will be set by save
            else
                raise MapperException, "#{action} action not implemented"
            end
        end
        
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
        
        def have_references?(element)
            raise MapperException, "Unimplemented"
        end
        
        ##############################################################
        #   Save (insert and update)                                 #
        ##############################################################
        
        def before_save(obj, mode)
            normalize(obj)
            @model.elements_array.each do |el|
                raise MapperException, "Element #{el.name} is required" if (el.required? && obj.element_modified?(el) && !obj.element_has_value?(el))
                if (el.unique? && !el.integrated? && obj.element_modified?(el))
                    existent = @model.find(el.name => obj.get(el))
                    if (mode == :insert && existent.length > 0) || (mode == :update && existent.length > 1)
                        raise MapperException, "Element #{el.name} is not unique"
                    end
                end
            end
        end
        
        def after_save(obj, mode)
            obj.reset_modified_elements
        end
        
        def save(obj, request=nil)
            
            if (@model.extended_models)
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
            normalize(obj)
            before_save(obj, save_mode)
            if (@model.extended_models)
                @model.extended_models.each do |m, el|
                    obj.get(el).save if obj.element_modified?(el)
                end
            end
            if (save_mode == :update)
                do_update(obj)
            else
                do_insert(obj)
            end
            save_associations(obj)
            after_save(obj, save_mode)
        end

        
        def save_associations(obj)
            @model.elements_array.select{ |el| mapped?(el) && !el.integrated? &&
                    !have_references?(el) && obj.element_has_value?(el) }.each do |el|
                save_element_associations(obj, el)
            end
        end
        
        def save_element_associations(obj, element)
            if (element.attributes[:junction])
                element.mapper.delete({element.attributes[:reverse] => obj})
                val = obj.get(element)
                if (val.is_a?(QuerySet) && val.model == element.type) # construct the junction
                    qs = QuerySet.static(element.model, val.map{ |el_obj|
                        {element.attributes[:reverse] => obj, element.attributes[:junction_their_element] => el_obj}
                    })
                    val = qs
                elsif (val.is_a?(QuerySet))
                    val.each do |row|
                        row.set(element.attributes[:reverse], obj)
                    end
                end
                val.insert
            else
                associated = obj.get(element)
                if (element.multiple? && element.owned?)
                    condition = Condition.and
                    associated.each do |child|
                        condition_row = Condition.or
                        element.model.primary_keys.each{ |el| condition_row.set(el.name, '<>', child.get(el))}
                        condition << condition_row
                    end
                    element.mapper.delete(condition)
                end
                associated.set(element.reverse, obj)
                associated.save
            end
        end
        
        def save_all(root)
            uow = UnitOfWork.new
            uow.add(root)
            @model.elements.select{ |n, el| mapped?(el) && el.model? && root.element_has_value?(el) && root.get(el).modified? }.each do |name, element|
                uow.add(root.send(name))
            end
            uow.run()
        end
        
        def insert(obj)
            before_save(obj, :insert)
            do_insert(obj)
            after_save(obj, :insert)
        end
        
        def update(obj)
            before_save(obj, :update)
            do_update(obj)
            after_save(obj, :update)
        end
        
        def bulk_update(values, conditon)
        end
        
        def delete(obj_or_condition)
            if (obj_or_condition.is_a?(BaseModel))
                obj = obj_or_condition
                condition = Condition.and
                @model.primary_keys.each do |key|
                    condition[key.name] = map_condition_value(key.type, obj.get(key))
                end
                Spider::Logger.debug("Deleting with condition:")
                Spider::Logger.debug(condition)
            else

                condition = obj_or_condition.is_a?(Condition) ? obj_or_condition : Condition.new(obj_or_condition)
            end
            prepare_query_condition(condition)
            do_delete(condition)
        end
        
        def delete_all!
            raise MapperException, "Unimplemented"
        end
        
        def do_delete(obj)
            raise MapperException, "Unimplemented"
        end
        
        def do_insert(obj)
            raise MapperException, "Unimplemented"
        end
        
        def do_update(obj)
            raise MapperException, "Unimplemented"
        end
        
        def lock(obj=nil, mode=:exclusive)
            raise MapperException, "Unimplemented"
        end
        
        def sequence_next(name)
            raise MapperException, "Unimplemented"
        end
        
        ##############################################################
        #   Load (and find)                                          #
        ##############################################################        
        
        def load_element(objects, element)
            load(objects, Query.new(nil, [element.name]))
        end
        
        def load_element!(objects, element)
            load(objects, Query.new(nil, [element.name]), :no_expand_request => true)
        end
        
        def load(objects, query, options={})
            objects = queryset_siblings(objects) unless objects.is_a?(QuerySet)
            request = query.request
            condition = Condition.or
            objects.each do |obj|
                condition << obj.keys_to_condition
            end
            return find(Query.new(condition, request), objects, options)
        end
        
        
        def find(query, query_set=nil, options={})
            set = nil
            Spider::Model.with_identity_mapper do |im|
                im.put(query_set)
                if (@model.attributes[:condition])
                    query.condition = Condition.and(query.condition, @model.attributes[:condition])
                end
                expand_request(query.request) unless options[:no_expand_request]
                query = prepare_query(query, query_set)
                query.request.total_rows = true unless query.request.total_rows = false
                result = fetch(query)
                set = query_set || QuerySet.new(@model)
                set.loaded = true
                set.index_by(*@model.primary_keys)
                set.query = query
                if !result || result.empty?
                    set.each do |obj|
                        query.request.keys.each do |element_name|
                            obj.set_loaded_value(element_name, nil) unless @model.elements[element_name].integrated?
                        end
                    end
                    return set
                end
                set.total_rows = result.total_rows
                result.each do |row|
                    obj =  map(query.request, row, set.model)
                    next unless obj
                    search = {} 
                    @model.primary_keys.each{ |k| search[k.name] = obj.get(k.name) }
                    obj_res = set.find(search)  # FIXME: find a better way
                    if (obj_res && obj_res[0])
                        obj_res[0].merge!(obj)
                        obj.loaded_elements.each{ |name, bool| set.element_loaded(name) }
                    else
                        set << obj
                    end
                    @raw_data[obj.object_id] = row
                end
#                delay_put = true if (@model.primary_keys.select{ |k| @model.elements[k.name].integrated? }.length > 0)

                set = get_external(set, query)
                # FIXME: avoid the repetition
                set.each do |obj|
                    query.request.keys.each do |element_name|
                        obj.set_loaded_value(element_name, nil) unless obj.element_loaded?(element_name) || @model.elements[element_name].integrated?
                    end
                end
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
        
        def count(condition)
            query = Query.new(condition)
            result = fetch(query)
            return result.length
        end
        
        def fetch(query)
            raise MapperException, "Unimplemented"
        end
        
        
        # FIXME: cleanup "other", polymorphs should be passed in a better way
        def map(request, result, obj)
            raise MapperException, "Unimplemented"
        end
        
        # Load external elements, according to query, 
        # and merge them into an object or a QuerySet
        def get_external(objects, query)
            objects = queryset_siblings(objects) unless objects.is_a?(QuerySet)
            return objects if objects.length < 1
            got_external = {}
            get_integrated = {}
            query.request.each_key do |element_name|
                element = @model.elements[element_name]
                next unless element && mapped?(element)
                next if objects.element_loaded?(element_name)
                next unless element.reverse # FIXME
                if element.integrated?
                   get_integrated[element.integrated_from] ||= Request.new
                   get_integrated[element.integrated_from][element.integrated_from_element] = query.request[element_name]
                elsif element.model?
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
        
        def get_external_element(element, query, objects)
            Spider::Logger.debug("Getting external element #{element.name} for #{@model}")
            if (have_references?(element))
                return load_element(objects, element)
            end
            sub_request = Request.new
            @model.primary_keys.each{ |key| sub_request[key.name] = true }
            sub_request[element.attributes[:reverse]] = true
            condition = Condition.or
            index_by = []
            @model.primary_keys.each{ |key| index_by << :"#{element.attributes[:reverse]}.#{key.name}" }
            
            objects.each do |obj|
                condition_row = Condition.and
                @model.primary_keys.each do |key|
                    condition_row["#{element.attributes[:reverse]}.#{key.name}"] = obj.get(key)
                end
                condition << condition_row
            end
            unless condition.empty?                
                if (element.condition)
                    condition = Condition.and(condition, element.condition)
                end
                result = QuerySet.new(element.model).index_by(*index_by)
                result = result.mapper.find(Query.new(condition, sub_request), result)
                result.loaded = true
                return associate_external(element, objects, result)
            end
            return nil
        end
        
        def queryset_siblings(obj)
            return QuerySet.new(@model, obj) unless obj._parent
            path = []
            seen = {obj => true}
            while (obj._parent && !seen[obj._parent])
                path.unshift(obj._parent_element) if (obj._parent_element) # otherwise it's a query set
                obj = obj._parent
                seen[obj] = true
            end
            res = path.empty? ? obj : obj.all_children(path)
            res = QuerySet.new(@model, res) unless res.is_a?(QuerySet)
            return res
        end
        

        
        def map_back_value(type, value)
            raise MapperException, "Unimplemented"
        end
        
        
        ##############################################################
        #   Strategy                                                 #
        ##############################################################

        def prepare_query(query, obj=nil)
            prepare_query_request(query.request, obj)
            prepare_query_condition(query.condition)
            return query
        end
        
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
                    request.request(name)
                end
            end
        end
        
        # FIXME: better name, move somewhere else
        def prepare_query_condition(condition)
            condition.each_with_comparison do |k, v, c|
                raise MapperException, "Condition for nonexistent element #{k}" unless element = @model.elements[k]
                if (element.integrated?)
                    condition.delete(k)
                    integrated_from = element.integrated_from
                    integrated_from_element = element.integrated_from_element
                    condition.set("#{integrated_from.name}.#{integrated_from_element}", c, v)
                end
                if (element.type.subclass_of?(Spider::DataType) && !v.is_a?(element.type))
                    condition[k] = element.type.new(v)
                end
            end
            condition.subconditions.each do |sub|
                prepare_query_condition(sub)
            end
        end
        
        
    end
    
    ##############################################################
    #   MapperTask                                               #
    ##############################################################
    
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
            p "Executing #{@action} on #{@object}"
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
        
        
        def inspect
            if (@action && @object)
                str = "#{@action} on #{@object}\n"
                str += "-dependencies:\n"
                @dependencies.each do |dep|
                    str += "---#{dep.action} on #{dep.object}\n"
                end
            else
                str = "Root Task"
            end
            return str
        end
        
    end
    
    
    ##############################################################
    #   Exceptions                                               #
    ##############################################################
    
    class MapperException < RuntimeError
    end
    
end; end