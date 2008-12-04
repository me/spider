require 'spiderfw/model/mappers/mapper'
require 'fileutils'

module Spider; module Model; module Mappers

    class DbMapper < Spider::Model::Mapper

        def initialize(model, storage)
            super
        end
        
        
        ##############################################################
        #   Save (insert and update)                                 #
        ##############################################################
        
        def before_save(obj)
            @model.elements.select{ |n, el| 
                mapped?(el) && obj.element_has_value?(el) && el.has_single_reverse? 
            }.each do |name, element|
                # FIXME: cleanup
                if (element.multiple?)
                    obj.send(name).each { |o| o.send("#{element.attributes[:reverse]}=", obj) }
                else
                    obj.send(name).send("#{element.attributes[:reverse]}=", obj)
                end
            end
            super(obj)
        end
        
        def after_save(obj)
            @model.elements.select{ |n, el| 
                mapped?(el) && el.model? && obj.element_has_value?(el) && el.multiple? && !el.has_single_reverse?
            }.each do |name, element|
                save_associations(obj, element)
            end
        end
            
        
        def save_all(root)
            @storage.start_transaction if @storage.supports_transactions?
            super
            @storage.commit
        end
        
        # Inserts passed object into the database
        def do_insert(obj)
            @storage.start_transaction if @storage.supports_transactions?
            if (obj.class.managed? || !obj.primary_keys_set?)
                assign_primary_keys(obj)
            end
            sql, values = prepare_insert(obj)
            @storage.execute(sql, *values)
            if (delayed_primary_keys?)
                @model.primary_keys.each do |key|
                    obj.set_loaded_value(key, @storage.assigned_key(key))
                end
            end
            @storage.commit
        end
        
        def do_update(obj)
            @storage.start_transaction if @storage.supports_transactions?
            sql, values = prepare_update(obj)
            @storage.execute(sql, *values)
            @storage.commit
        end
        
        def do_delete(obj)
            #delete = prepare_delete(obj)
            del = {}
            condition = Condition.new_and
            @model.primary_keys.each do |key|
                condition[key.name] = map_condition_value(key.type, obj.get(key))
            end
            del[:condition], del[:joins] = prepare_condition(condition)
            del[:table] = @schema.table
            sql, values =  @storage.sql_delete(del)
            @storage.execute(sql, *values)
        end
        
        def sql_execute(sql, *values)
            @storage.execute(sql, *values)
        end
        
        
        def prepare_save(obj, save_mode)
            values = {}
            @model.each_element do |element|
                next unless mapped?(element)
                if (save_mode == :insert && element.attributes[:autoincrement] && !@storage.supports?(:autoincrement))
                    obj.set(element.name, @storage.sequence_next(schema.table, schema.field(element.name)))
                end
                if (!element.multiple? && obj.element_has_value?(element) && !element.added?)
                    next if (save_mode == :update && element.primary_key?)
                    next if (element.model? && !schema.has_foreign_fields?(element.name))
                    next if (element.model? && !obj.get(element).primary_keys_set?)
                    next if (element.integrated?)
                    if (element.model?)
                        element_val = obj.get(element.name)
                        element.model.primary_keys.each do |key|
                            store_key = schema.foreign_key_field(element.name, key.name)
                            values[store_key] = map_save_value(key.type, element_val.get(key.name), save_mode)
                        end
                    else
                        store_key = schema.field(element.name)
                        values[store_key] = map_save_value(element.type, obj.send(element.name), save_mode)
                    end
                end
            end
            return {
                :values => values
            }
        end
        
        def prepare_insert(obj)
            save = prepare_save(obj, :insert)
            save[:table] = @schema.table
            return @storage.sql_insert(save)
        end
        
        def prepare_update(obj)
            save = prepare_save(obj, :update)
            condition = Condition.new_and
            @model.primary_keys.each do |key|
                condition[key.name] = map_condition_value(key.type, obj.get(key))
            end
            prepare_query_condition(condition)
            save[:condition], save[:joins] = prepare_condition(condition)
            save[:table] = @schema.table
            return @storage.sql_update(save)
        end
         
         def save_associations(obj, element, add=false)
             # FIXME: this is messy
             table = @schema.junction_table_name(element.name)
             local_values = {}
             @model.primary_keys.each { |key| local_values[@schema.junction_table_our_field(element.name, key.name)] = map_condition_value(key.type, obj.get(key)) }
             unless(add)
                 delete = {
                     :table => table,
                     :condition => {
                         :conj => 'AND',
                         :values => local_values.map{ |field, val| [field, '=', val] }
                     }
                 }
                 sql, bind_vars = @storage.sql_delete(delete)
                 @storage.execute(sql, *bind_vars)
             end
             #sql += "AND ("+element_values.map{ |field, val| "#{field} <> #{val}"}.join(" OR ")+")"
#             @storage.execute(sql, local_values.map{ |val| val })
             obj.get(element).each do |sub_obj|
                 element_values = {}
                 element.model.primary_keys.each { |key| element_values[@schema.junction_table_their_field(element.name, key.name)] = map_save_value(key.type, sub_obj.get(key), :insert)}
                 element.model.added_elements.each { |added| element_values[@schema.junction_table_added_field(element.name, added.name)] = map_save_value(added.type, sub_obj.get(added), :insert) if (sub_obj.element_has_value?(added)) }
                 insert = {
                     :table => table,
                     # FIXME: local_values are prepared for condition
                     :values => local_values.merge(element_values)
                 }
                 # sql = "INSERT INTO #{table} (#{local_values.keys.join(',')}, #{element_values.keys.join(',')}) VALUES ("+
                 #         (local_values.values+element_values.values).map{'?'}.join(',') + ")"
                 sql, bind_vars = @storage.sql_insert(insert)
                 @storage.execute(sql, bind_vars)
                 #end
             end
         end
        
        ##############################################################
        #   Loading methods                                          #
        ##############################################################
        
        def count(condition)
            storage_query = prepare_select(query)
            storage_query[:type] = :count
            return @storage.query(storage_query)
        end
        
        def fetch(query)
            storage_query = prepare_select(query)
            if (storage_query)
                result = @storage.query(storage_query)
                result.total_rows = @storage.total_rows if (query.request.total_rows) 
            end
            return result
        end
        
        def map(request, result, obj_or_model)
            # FIXME: cleanup; get the values in a hash in both cases, then decide
            if (obj_or_model.is_a?(Class))
                pks = {}
                obj_or_model.primary_keys.each do |key|
                    result_value = result[schema.field(key.name)]
                    pks[key.name] = map_back_value(key.type, result_value)
                end
                obj = Spider::Model.get(obj_or_model, pks)
            else
                obj = obj_or_model
            end     
            request.keys.each do |element_name|
                element = @model.elements[element_name]
                next if !element || element.integrated?
                if (element.model? && schema.has_foreign_fields?(element.name))
                    pks = {}
                    element.model.primary_keys.each do |key| 
                        pks[key.name] = result[schema.foreign_key_field(element_name, key.name)]
                    end
                    sub_obj = Spider::Model.get(element.model, pks)
                    obj.set_loaded_value(element, sub_obj)
                end
                next if element.model?
                result_value = result[schema.field(element_name)]
                obj.set_loaded_value(element, map_back_value(element.type, result_value))
            end
            Spider::Model.identity_mapper_put(obj)
            if (request.polymorphs)
                request.polymorphs.each do |model, polym_request|
                    polym_result = {}
                    polym_request.keys.each do |element_name|
                        field = model.mapper.schema.field(element_name)
                        res_field = "#{model.mapper.schema.table}_#{field}"
                        polym_result[field] = result[res_field] if result[res_field]
                    end
                    if (!polym_result.empty?)
                        polym_obj = model.new
                        polym_obj.mapper.map(polym_request, polym_result, polym_obj)
                        polym_obj.set_loaded_value(model.extended_models[@model], obj)
                        obj = polym_obj
                        break
                    end
                end                    
            end
            return obj
        end

        def prepare_query_request(request, obj=nil)
            # FIXME: move to strategy
            @model.elements.select{ |name, element| 
                !element.model? && (!obj || !obj.element_loaded?(element))
            }.each do |name, element|
                request[element] = true
            end
            super(request, obj)
        end
        
        def prepare_select(query)
            elements = query.request.keys.select{ |k| mapped?(k) }
            keys = []
            types = {}
            elements.each do |el|
                element = @model.elements[el.to_sym]
                next if !element || !element.type || element.integrated?
                if (element.model? && !element.multiple? && schema.has_foreign_fields?(el))
                    element.model.primary_keys.each do |key|
                        field = schema.foreign_key_field(el, key.name)
                        keys << field
                        types[field]  = map_type(key.type)
                    end
                elsif (!element.model? && !element.added?)
                    field = schema.qualified_field(el)
                    keys << field
                    types[field] = map_type(element.type)
                end
            end
            condition, joins = prepare_condition(query.condition)
            if (query.polymorphs?)
                query.request.polymorphs.each do |model, polym_request|
                    extension_element = model.extended_models[@model]
                    model.mapper.prepare_query_request(polym_request)
                    polym_request.reject!{|k, v| 
                        model.elements[k].integrated? && model.elements[k].integrated_from.name == extension_element
                    }
                    polym_select = model.mapper.prepare_select(Query.new(nil, polym_request)) # FIXME!
                    polym_select[:keys].map!{ |key| "#{key} AS #{key.gsub('.', '_')}"}
                    keys += polym_select[:keys]
                    join_fields = {}
                    @model.primary_keys.each do |key|
                        from_field = @schema.field(key.name)
                        to_field = model.mapper.schema.foreign_key_field(extension_element, key.name)
                        join_fields[from_field] = to_field 
                    end
                    # FIXME: move to get_join
                    joins << {
                        :type => :left_outer,
                        :from => @schema.table,
                        :to => model.mapper.schema.table,
                        :keys => join_fields
                    }
                end
            end
            #tables = ([@schema.table] + joins.map{ |join| join[0] } + joins.map{ |join| join[1] }).flatten.uniq
            tables = [@schema.table]
            order = prepare_order(query)
            joins = prepare_joins(joins)
            return nil if (keys.empty?)
            return {
                :query_type => :select,
                :keys => keys,
                :types => types,
                :tables => tables,
                :condition => condition,
                :joins => joins,
                :order => order,
                :offset => query.offset,
                :limit => query.limit
            }
        end
        
        def prepare_joins(joins)
            h = {}
            joins.each do |join|
                h[join[:from]] ||= {}
                h[join[:from]][join[:to]] ||= []
                h[join[:from]][join[:to]] << join
            end
            return h
        end
        
        # def prepare_joins(joins)
        #     h = {}
        #     joins.each do |join|
        #         from_table, to_table, on_fields = join
        #         if (h[from_table] && h[from_table][to_table])
        #             h[from_table][to_table].merge(on_fields)
        #         else
        #             h[from_table] ||= {}
        #             h[from_table][to_table] = on_fields
        #         end
        #     end
        #     return h
        # end
        
        
        def prepare_condition(condition)
            condition.each_with_comparison do |k, v, comp|
                # normalize condition values
                element = @model.elements[k.to_sym]
                if (!v.is_a?(Condition) && element.model?)
                    condition.delete(element.name)
                    if (v.is_a?(BaseModel)) 
                        element.model.primary_keys.each do |primary_key|
                            condition.set("#{element.name}.#{primary_key.name}", '=', v.get(primary_key))
                        end
                    elsif (element.model.primary_keys.length == 1)
                        v = Condition.new({element.model.primary_keys[0].name => v})
                        condition.set(element.name, '=', v)
                    end
                end
            end 
            bind_values = []
            joins = []
            cond = {}
            remaining_condition = Condition.new # TODO: implement
            cond[:conj] = condition.conjunction.to_s
            cond[:values] = []
            condition.each_with_comparison do |k, v, comp|
                element = @model.elements[k.to_sym]
                next unless mapped?(element)
                if (element.model?)
                    if (!element.multiple? && v.select{ |key, value| !element.model.elements[key].primary_key? }.empty?)
                        # 1/n <-> 1 with only primary keys
                        element_sql = ""
                        element_cond = {:conj => 'AND', :values => []}
                        v.each_with_comparison do |el_k, el_v, el_comp|
                            field = schema.foreign_key_field(element.name, el_k)
                            op = comp ? comp : '='
                            field_cond = [field, op,  map_condition_value(element.model.elements[el_k.to_sym].type, el_v)]
                            element_cond[:values] << field_cond
                        end
                        cond[:values] << element_cond
                    else
                        if (element.storage == @storage)
                            element_condition, element_joins = element.mapper.prepare_condition(v)
                            joins += element_joins
                            joins << get_join(element)
                            cond[:values] << element_condition
                        else
                           remaining_condition ||= Condition.new
                           remaining_condition.set(k, comp, v)
                        end
                    end
                elsif(schema.field(element.name))
                    field = schema.qualified_field(element.name)
                    op = comp ? comp : '='
                    cond[:values] << [field, op, map_condition_value(@model.elements[k.to_sym].type, v)]
                end
                
            end
            sub_sqls = []
            sub_bind_values = []
            condition.subconditions.each do |sub|
                sub_res = self.prepare_condition(sub)
                cond[:values] << sub_res[0]
                joins += sub_res[1]
                remaining_condition += sub_res[2]
            end
            return [cond, joins, remaining_condition]
        end
        
        def get_join(element)
            return unless element.model?
            element_table = element.mapper.schema.table
            
            if (element.multiple? && element.has_single_reverse?) # 1 <-> n
                #buh
            elsif (element.multiple?) # n <-> n
                #boh
            else # n <-> 1
                keys = {}
                element.model.primary_keys.each do |key|
                    keys[@schema.foreign_key_field(element.name, key.name)] = element.mapper.schema.field(key.name)
                end
                join = {
                    :type => :inner,
                    :from => schema.table,
                    :to => element.mapper.schema.table,
                    :keys => keys
                }
            end
            return join
        end
        
        def prepare_order(query)
            o = []
            query.order.each do |order|
                dir = order[1] ? order[1] : ''
                o << [order[0], dir]
            end
            return o
        end
        
        def map_type(type)
            if (type.is_a? Spider::DataTypes::DataType)
                return type.maps_to
            end
            return type
        end
        
        def map_value(type, value, mode=nil)
             if type.class == Class && type.subclass_of?(Spider::Model::BaseModel)
                 value = type.primary_keys.map{ |key| value.send(key.name) }
             else
                 case type
                 when 'bool'
                     value = value ? 1 : 0
                 end
             end
             return value
        end
        
        # Prepares a value going to be bound to an insert or update statement
        # This method is also called by map_condition_value
         def map_save_value(type, value, save_mode)
             value = map_value(type, value, :save)
             return @storage.value_for_save(type, value, save_mode)
         end

        # Prepares a value for an sql condition.
        def map_condition_value(type, value)
            return value if ( type.class == Class && type.subclass_of?(Spider::Model::BaseModel) )
            value = map_value(type, value, :condition)
            return @storage.value_for_condition(type, value)
        end

        def map_back_value(type, value)
            type = type.respond_to?('basic_type') ? type.basic_type : type
            value = value[0] if value.class == Array
            case type
            when 'int'
                return value.to_i
            when 'real'
                return value.to_f
            when 'bool'
                return value ? true : false
            end
            return nil unless value
            case type
            when 'dateTime'
                return DateTime.parse(value)
            end
            return value
        end
        
        ##############################################################
        #   External elements                                        #
        ##############################################################
        
        
        # Load an external element, passing the query to it, and merge the results
        # into an object or an QuerySet, passed as the third param
        # Returns the object or the QuerySet
        def get_external_element(element, query, objects)
            element_keys = element.model.primary_keys
            # If the element is not multiple and all requests are primary keys, we already have all we need
            if ( !element.multiple? &&  (query.request.keys - element_keys.map{ |key| key.name }).size == 0 )
                objects.each do |obj|
                    current_sub = obj.get(element)
                    pks = {}
                    element_keys.each do |key|
                        val = @raw_data[obj.object_id][schema.foreign_key_field(element.name, key.name)]
                        val = map_back_value(element.model.elements[key.name].type, val)
                        pks[key.name] = val
                    end
                    sub_obj = current_sub.is_a?(Spider::Model::BaseModel) ? current_sub : Model.get(element.model, pks)
                    obj.set_loaded_value(element, sub_obj)
                end
                result = objects
            else
                # FIXME: have to merge the original query?
                sub_query = Query.new
                sub_query.request = query.request || Request.new
                sub_query.condition.conjunction = 'or'
                index_by = []
                if (element.multiple? && !element.has_single_reverse?) # n <-> n
                    element_keys.each { |key| index_by << key }
                    associations = get_associations(element, query, objects)
                    associations.each do |key, rows|
                        rows.each do |row|
                            condition_row = Condition.new_and
                            element_keys.each do |key|
                                condition_row[key.name] = row[key.name]
                            end
                            sub_query.condition << condition_row
                        end
                    end
                else
                    associations = nil
                    objects.each_index do |index|
                        obj = objects[index]
                        condition_row = Condition.new_and
                        if (!element.multiple? && schema.has_foreign_fields?(element.name)) # 1|n <-> 1
                            element_keys.each do |key|
                                condition_row[key.name] = @raw_data[obj.object_id][schema.foreign_key_field(element.name, key.name)]
                            end
                            index_by = element_keys
                        elsif (element.has_single_reverse?) # 1 <-> n|1
                            sub_request = Request.new
                            @model.primary_keys.each{ |key| sub_request[key.name] = true }
                            sub_query.request[element.attributes[:reverse]] = sub_request
                            @model.primary_keys.each do |key|
                                condition_row["#{element.attributes[:reverse]}.#{key.name}"] = obj.get(key)
                            end
                            @model.primary_keys.each{ |key| index_by << :"#{element.attributes[:reverse]}.#{key.name}" }
                        end
                        sub_query.condition << condition_row
                    end
                end
                if (element.condition)
                    new_cond = Condition.new_and
                    new_cond << element.condition
                    new_cond << sub_query.condition
                    sub_query.condition = new_cond
                end
                element_queryset = QuerySet.new(element.model)
                unless (sub_query.condition.empty?)
                    element_queryset.index_by(*index_by)
                    element_queryset = element_queryset.mapper.find(sub_query, element_queryset)
                end
                result = associate_external(element, objects, element_queryset, associations)
            end
            return result
        end
        
        # For each object in an Array or a QuerySet ("objects" param), sets the value of element to the associated
        # objects found in element_query_set
        def associate_external(element, objects, element_query_set, associations=nil)
            primary_keys = @model.primary_keys
            element_keys = element.model.primary_keys
            if (associations) # n <-> n
                objects.each do |obj|
                    obj.set(element, QuerySet.new(element.model))
                    obj_key = primary_keys.map{ |key| obj.get(key) }.join(',')
                    obj_associations = associations[obj_key] || []
                    search_params = {}
                    obj_associations.each do |association_row|
                        element_keys.each do |key|
                            search_params[key.name] = association_row[key.name]
                        end
                        sub_obj = element_query_set.find(search_params)[0]
                        element.type.added_elements.each do |added|
                            sub_obj.set_loaded_value(added, element.mapper.map_back_value(added.type, association_row[added.name]))
                        end
                        obj.get(element) << sub_obj
                    end
                end 
            elsif ((element.multiple? || !@schema.has_foreign_fields?(element.name)) && element.has_single_reverse?) # 1 <-> n"
                # FIXME: should be already indexed!
                element_query_set.reindex
                objects.each do |obj|
                    search_params = {}
                    @model.primary_keys.each do |key|
                        field = @schema.field(key.name)
                        search_params[:"#{element.attributes[:reverse]}.#{key.name}"] = obj.get(key) #@raw_data[obj.object_id][field]
                    end
                    sub_res = element_query_set.find(search_params)
                    sub_res.each do |sub_obj|
                        sub_obj.set_loaded_value(element.attributes[:reverse], obj)
                    end
                    sub_res = sub_res[0] if !element.multiple?
                    obj.set_loaded_value(element, sub_res)
                end
            else # 1|n <-> 1
                # FIXME: should be already indexed, but is misssing associated objects
                element_query_set.reindex
                objects.each do |obj|
                    search_params = {}
                    element_keys.each do |key|
                        field = schema.foreign_key_field(element.name, key.name)
                        search_params[key.name] = @raw_data[obj.object_id][field]
                    end
                    found = element_query_set.find(search_params)
                    obj.set_loaded_value(element, found[0]) if found
                end
            end
            return objects
        end
        
        def get_associations(element, query, objects)
            x_table = @schema.junction_table_name(element.name)
            primary_keys = @model.primary_keys
            element_primary_keys = element.model.primary_keys
            select = {:tables => [x_table]}
            select[:keys] = primary_keys.map{ |key| @schema.junction_table_our_field(element.name, key.name) }
            select[:keys] += element_primary_keys.map{ |key| @schema.junction_table_their_field(element.name, key.name) }
            added_elements = element.type.added_elements
            if (added_elements.size > 0)
                select[:keys] += added_elements.map{ |added| @schema.junction_table_added_field(element.name, added.name) }
            end
            condition = {:conj => 'OR', :values => []}
            objects.each do |obj|
                sub_cond = {:conj => 'AND', :values => []}
                primary_keys.each do |key|
                    sub_cond[:values] << [@schema.junction_table_our_field(element.name, key.name), 
                        '=', map_condition_value(key.type, obj.get(key))]
                end
                condition[:values] << sub_cond
            end
            sql, bind_vars = @storage.sql_select(select)
            result = @storage.execute(sql, *bind_vars)
            associations = {}
            result.each do |row|
                obj_key = primary_keys.map{ |key| row[@schema.junction_table_our_field(element.name, key.name)] }.join(',')
                associations[obj_key] ||= []
                element_values = {}
                element_primary_keys.each{ |key| element_values[key.name] = row[@schema.junction_table_their_field(element.name, key.name)] }
                element.model.added_elements.each{ |added| element_values[added.name] = row[@schema.junction_table_added_field(element.name, added.name)]}
                associations[obj_key] << element_values
            end
            return associations
        end
        
        
        ##############################################################
        #   Primary keys                                             #
        ##############################################################
        
        def assign_primary_keys(obj)
            # may be implemented in model
        end
        
        def delayed_primary_keys?
            false
        end

        
        ##############################################################
        #   Storage strategy                                         #
        ##############################################################
        
        def get_dependencies(obj, action)
            deps = []
            task = MapperTask.new(obj, action)
            deps = []
            case action
            when :keys
                deps << [task, MapperTask.new(obj, :save)] unless obj.primary_keys_set?
            when :save
                elements = @model.elements.select{ |n, el| el.model? && obj.element_has_value?(el)}
                # n <-> n and n|1 <-> 1
                elements.select{ |n, el| !el.has_single_reverse? }.each do |name, element|
                    if (element.multiple?)
                        set = obj.send(element.name)
                        set.each do |set_obj|
                            deps << [task, MapperTask.new(set_obj, :keys)]
                        end
                    else
                        deps << [task, MapperTask.new(obj.send(element.name), :keys)]
                    end
                end
                elements.select{ |n, el| el.multiple? && el.has_single_reverse? }.each do |name, element|
                    set = obj.send(element.name)
                    set.each do |set_obj|
                        sub_task = MapperTask.new(set_obj, :save)
                        deps << [sub_task, MapperTask.new(obj, :keys)]
                    end
                end
            end
            return deps
        end
        
        
        ##############################################################
        #   Schema management                                        #
        ##############################################################

        def with_schema(*params, &proc)
            @schema_proc = proc
        end
        
        def define_schema(*params, &proc)
            @schema_define_proc = proc
        end

        def schema
            @schema ||= get_schema()
            return @schema
        end
        
        def get_schema()
            schema =  Spider::Model::Storage::Db::DbSchema.new()
            if (@schema_define_proc)
                schema.instance_eval(&@schema_define_proc)
            else
                generate_schema(schema)
            end
            if (@schema_proc)
                schema.instance_eval(&@schema_proc)
            end
            return schema
        end

        def generate_schema(schema)
            n = @model.name.sub('::Models', '')
            n.sub!(@model.app.name, @model.app.short_prefix) if @model.app.short_prefix
            schema.table = @storage.table_name(n)
            @model.each_element do |element|
                next if element.integrated?
                if (!element.model?)
                    type = element.custom_type? ? element.type.class.maps_to : element.type
                    schema.set_column(element.name,
                        :name => @storage.column_name(element.name),
                        :type => @storage.column_type(type, element.attributes),
                        :attributes => @storage.column_attributes(type, element.attributes)
                    )
                elsif (true) # FIXME: must have condition element.storage == @storage in some of the subcases
                    if (!element.multiple?) # 1/n <-> 1
                        element.type.primary_keys.each do |key|
                            next if key.model?
                            #key_column = element.mapper.schema.column(key.name)
                            schema.set_foreign_key(element.name, key.name, 
                                :name => @storage.column_name("#{element.name}_#{key.name}"),
                                :type => @storage.column_type(key.type, key.attributes),
                                :attributes => @storage.column_attributes(key.type, key.attributes)
                            )
                        end
                    elsif (!element.has_single_reverse?)
                        table_name = generate_junction_table_name(element)
                        junction_table = {}
                        junction_table[:name] = table_name
                        junction_table[:ours] = {}; junction_table[:theirs] = {}; junction_table[:added] = {}
                        @model.primary_keys.each do |key|
                            junction_table[:ours][key.name] = {
                                :name => @storage.column_name("#{@model.short_name}_#{key.name}"),
                                :type => @storage.column_type(key.type, key.attributes),
                                :attributes => @storage.column_attributes(key.type, key.attributes)
                            }
                        end
                        element.type.primary_keys.each do |key|
                            junction_table[:theirs][key.name] ={
                                :name => @storage.column_name("#{element.name}_#{key.name}"),
                                :type => @storage.column_type(key.type, key.attributes),
                                :attributes => @storage.column_attributes(key.type, key.attributes)
                            }
                        end
                        element.type.added_elements.each do |added|
                            junction_table[:added][added.name] = {
                                :name => @storage.column_name(added.name),
                                :type => @storage.column_type(added.type, added.attributes),
                                :attributes => @storage.column_attributes(added.type, added.attributes)
                            }
                        end
                        schema.set_junction_table(element.name, junction_table)
                    end
                end
            end
            return schema
        end
        
        # Helper function that generates a suitable name for a junction table
        def generate_junction_table_name(element)
            if (element.attributes[:reverse])
                reverse_element = element.model.elements[element.attributes[:reverse]]
            end
            # this model is the owner
            if (!reverse_element || element.attributes[:add_reverse] || element.attributes[:add_multiple_reverse] ||
                element.attributes[:superclass])
                table = [@model, element]
            # the other model is the owner
            elsif(reverse_element.attributes[:add_reverse])
                table = [element.model, reverse_element]
            # decide
            else
                table = [[@model, element], [element.model, reverse_element]].sort{ |a, b|
                    "#{a[0].name}_#{a[1].name}" <=> "#{b[0].name}_#{b[1].name}"
                }[0]
            end
            mod, el = table
            n = mod.name.to_s.sub('::Models', '')
            n.sub!(mod.app.name, mod.app.short_prefix) if mod.app && mod.app.short_prefix
            n += '_' + el.name.to_s
            return @storage.table_name(n)
        end
        
        private :generate_junction_table_name

        def sync_schema(force=false)
            schema_description = schema.get_all_schemas
            schema_description.each do |table_name, table_schema|
                if @storage.table_exists?(table_name)
                    alter_table(table_name, table_schema, force)
                else
                    create_table(table_name, table_schema)
                end
            end
        end

        def create_table(table_name, fields)
            fields = fields.map{ |name, details| {
              :name => name,
              :type => details[:type],
              :attributes => details[:attributes]  
            } }
            @storage.create_table({
                :table => table_name,
                :fields => fields
            })
        end

        def alter_table(name, fields, force=nil)
            current = @storage.describe_table(name)
            add_fields = []
            alter_fields = []
            all_fields = []
            unless (force)
                unsafe = []
                fields.each_key do |field|
                    field_hash = {
                        :name => field, 
                        :type => fields[field][:type], 
                        :attributes => fields[field][:attributes]
                    }
                    all_fields << field_hash
                    if (!current[field])
                        add_fields << field_hash
                    else
                        type = fields[field][:type]
                        attributes = fields[field][:attributes]
                        attributes ||= {}
                        if (!@storage.schema_field_equal?(current[field], fields[field]))
                            Spider.logger.debug("DIFFERENT: #{field}")
                            Spider.logger.debug(current[field])
                            Spider.logger.debug(fields[field])
                            unless @storage.safe_schema_conversion?(current[field], fields[field])
                                unsafe << field 
                            end
                            alter_fields << field_hash
                        end
                    end
                end
                raise SchemaSyncUnsafeConversion.new(unsafe) unless unsafe.empty?
            end
            @storage.alter_table({
                :table => name,
                :add_fields => add_fields,
                :alter_fields => alter_fields,
                :all_fields => all_fields
            })
        end

    end

    class SchemaSyncUnsafeConversion < RuntimeError
        attr :fields
        def initialize(fields)
            @fields = fields
        end
        def to_s
            "Unsafe conversion on fields #{fields}"
        end
    end

end; end; end
