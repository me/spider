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
        
        def save(obj)
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
            super
            @model.elements.select{ |n, el| 
                mapped?(el) && el.model? && obj.element_has_value?(el) && el.multiple? && !el.has_single_reverse?
            }.each do |name, element|
                save_associations(obj, element)
            end
        end
            
        
        def save_all(root)
            @storage.start_transaction if @storage.supports_transactions?
            uow = UnitOfWork.new
            uow.add(root)
            @model.elements.select{ |n, el| mapped?(el) && el.model? && root.element_has_value?(el) }.each do |name, element|
                uow.add(root.send(name))
            end
            uow.run()
            @storage.commit
        end
        
        # Inserts passed object into the database
        def insert(obj)
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
        
        def update(obj)
            @storage.start_transaction if @storage.supports_transactions?
            sql, values = prepare_update(obj)
            @storage.execute(sql, *values)
            @storage.commit
        end
        
        
        def prepare_save(obj, save_mode)
            values = {}
            @model.each_element do |element|
                if (mapped?(element) && !element.multiple? && obj.element_has_value?(element) && !element.added?)
                    next if (save_mode == :update && element.primary_key?)
                    next if (element.model? && !schema.has_foreign_fields?(element))
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
                :values => values,
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
            save[:condition], save[:joins] = prepare_condition(condition)
            save[:table] = @schema.table
            return @storage.sql_update(save)
        end
         
         def save_associations(obj, element)
             # FIXME: this is messy
             table = @schema.junction_table_name(element.name)
             local_values = {}
             @model.primary_keys.each { |key| local_values[@schema.junction_table_our_field(element.name, key.name)] = map_condition_value(key.type, obj.get(key)) }
             delete = {
                 :table => table,
                 :condition => {
                     :conj => 'AND',
                     :values => local_values.map{ |field, val| [field, '=', val] }
                 }
             }
             sql, bind_vars = @storage.sql_delete(delete)
             @storage.execute(sql, *bind_vars)
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
        
        def map(request, result, obj)
            request.keys.each do |element_name|
                element = @model.elements[element_name]
                next if !element || element.model?
                result_value = result[@schema.field(element_name)]
                obj.set_loaded_value(element, map_back_value(element.type, result_value))
            end
            return obj
        end
        
        def prepare_query(query)
            # FIXME: move to strategy
            @model.elements.select{ |name, element| !element.model? }.each do |name, element|
                query.request[element] = true
            end
            super(query)
           
            return query
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
            joins = prepare_joins(joins)
            tables = ([@schema.table] + joins.map{ |join| join[0] } + joins.map{ |join| join[1] }).flatten.uniq
            order = prepare_order(query)
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
                from_table, to_table, on_fields = join
                if (h[from_table] && h[from_table][to_table])
                    h[from_table][to_table].merge(on_fields)
                else
                    h[from_table] ||= {}
                    h[from_table][to_table] = on_fields
                end
            end
            return h
        end
        
        
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
                else
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
                join = [schema.table, element.mapper.schema.table, keys]
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
                    sub_obj = current_sub.is_a?(Spider::Model::BaseModel) ? current_sub : element.model.new()
                    element_keys.each do |key|
                        val = @raw_data[obj.object_id][schema.foreign_key_field(element.name, key.name)]
                        val = map_back_value(element.model.elements[key.name].type, val)
                        sub_obj.set_loaded_value(key, val)
                        obj.set_loaded_value(element, sub_obj)
                    end
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
                        search_params[:"#{element.attributes[:reverse]}.#{key.name}"] = @raw_data[obj.object_id][field]
                    end
                    sub_res = element_query_set.find(search_params)
                    sub_res = sub_res[0] if sub_res && !element.multiple?
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
            schema.table = @storage.table_name(@model.name.sub('::Models', ''))
            @model.each_element do |element|
                if (!element.model?)
                    type = element.custom_type? ? element.type.class.maps_to : element.type
                    schema.set_column(element.name,
                        :name => @storage.column_name(element.name),
                        :type => @storage.column_type(type),
                        :attributes => @storage.column_attributes(type, element.attributes)
                    )
                elsif (true) # FIXME: must have condition element.storage == @storage in some of the subcases
                    if (!element.multiple?) # 1/n <-> 1
                        element.type.primary_keys.each do |key|
                            #key_column = element.mapper.schema.column(key.name)
                            schema.set_foreign_key(element.name, key.name, 
                                :name => @storage.column_name("#{element.name}_#{key.name}"),
                                :type => @storage.column_type(key.type),
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
                                :type => @storage.column_type(key.type),
                                :attributes => @storage.column_attributes(key.type, key.attributes)
                            }
                        end
                        element.type.primary_keys.each do |key|
                            junction_table[:theirs][key.name] ={
                                :name => @storage.column_name("#{element.name}_#{key.name}"),
                                :type => @storage.column_type(key.type),
                                :attributes => @storage.column_attributes(key.type, key.attributes)
                            }
                        end
                        element.type.added_elements.each do |added|
                            junction_table[:added][added.name] = {
                                :name => @storage.column_name(added.name),
                                :type => @storage.column_type(added.type),
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

            element_prefix = @storage.table_name(element.type.name.sub('::Models', '').gsub('.', '_'))
            model_prefix = @storage.table_name(@model.name.sub('::Models', ''))
            common = -1
            common_prefix = ""
            model_prefix.split(//).each_index do |i|
                break if model_prefix[i] != element_prefix[i]
                common += 1;
            end
            if (common > -1)
                common_prefix = model_prefix[0..common]
                model_prefix = model_prefix[common+1..model_prefix.length-1]
                element_prefix = element_prefix[common+1..element_prefix.length-1]
            end
            model_part = model_prefix+"_"+element.name.to_s
            element_part = element_prefix
            if (element.attributes[:reverse])
                reverse = element.attributes[:reverse]
            else
                element.type.elements.each do |name, el|
                    if (el.type == @model && el.attributes[:reverse] == element.name)
                        reverse = el.name
                        break
                    end
                end
            end
            if (reverse)
                element_part += '_'+reverse.to_s
            end
            parts = [model_part, element_part].sort
            table_name = common_prefix + parts.join('_x_')
            return table_name
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

        def create_table(name, fields)
            sql_fields = ""
            sql = @storage.sql_create_table({
                :table => name,
                :fields => fields
            })
            @storage.execute(sql)
        end

        def alter_table(name, fields, force=nil)
            current = @storage.describe_table(name)
            unless (force)
                unsafe = []
                fields.each_key do |field|
                    next unless current[field]
                    type = fields[field][:type]
                    attributes = fields[field][:attributes]
                    attributes ||= {}
                    if (type != current[field][:type])
                        unsafe << field unless safe_schema_conversion?(current[field][:type], type)
                    elsif (attributes[:length] && current[field][:length] && attributes[:length] < current[field][:length])
                        unsafe << [field, "#{current[field][:type]}(#{current[field][:length]})", "#{type}(#{attributes[:length]})"]
                    end
                end
                raise SchemaSyncUnsafeConversionException.new(unsafe) unless unsafe.empty?
            end
            sqls = @storage.sql_alter_table({
                :table => name,
                :fields => fields
            })
            sqls.each do |sql|
                @storage.execute(sql)
            end
        end
        
        def safe_schema_conversion(old_type, new_type)
            return false
        end

    end

    class SchemaSyncUnsafeConversionException < RuntimeError
        attr :fields
        def initialize(fields)
            @fields = fields
        end
    end

end; end; end
