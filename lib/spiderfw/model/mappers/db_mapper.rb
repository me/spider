require 'spiderfw/model/mappers/mapper'
require 'FileUtils'

module Spider; module Model; module Mappers

    class DbMapper < Spider::Model::Mapper

        def initialize(model, storage)
            super
            @raw_data = {}
        end
        
        
        ##############################################################
        #   Save (insert and update)                                 #
        ##############################################################
        
        def save(obj)
            @model.elements.select{ |n, el| obj.element_has_value?(el) && el.has_single_reverse? }.each do |name, element|
                obj.send(name).each { |o| o.send("#{element.attributes[:reverse]}=", obj) }
            end
            super
            @model.elements.select{ |n, el| 
                el.model? && obj.element_has_value?(el) && el.multiple? && !el.has_single_reverse?
            }.each do |name, element|
                save_associations(obj, element)
            end
        end
            
        
        def save_all(root)
            uow = UnitOfWork.new
            uow.add(root)
            @model.elements.select{ |n, el| el.model? && root.element_has_value?(el) }.each do |name, element|
                uow.add(root.send(name))
            end
            uow.run()
        end
        
        # Inserts passed object into the database
        def insert(obj)
            if (obj.class.managed?)
                id = next_sequence('id')
                obj.assign_id(id)
            end
            sql, values = prepare_insert(obj)
            @storage.execute(sql, *values)
        end
        
        def update(obj)
            sql, values = prepare_update(obj)
            @storage.execute(sql, *values)
        end
        
        
        
        def prepare_save(obj)
            keys = []
            values = []
            @model.each_element do |element|
                if (!element.multiple? && obj.element_has_value?(element) && !element.added?)
                    if (element.model?)
                        element.model.primary_keys.each do |key|
                            keys.push(schema.foreign_key_field(element.name, key.name))
                            val = obj.get(element.name).get(key.name)
                            val = prepare_value(key.type, val)
                            values.push(val)
                        end
                    else
                        keys.push(schema.field(element.name))
                        val = obj.send(element.name)
                        val = prepare_value(element.type, val)
                        values.push(val)
                    end
                end
            end
            keys.flatten!
            return [keys, values]
        end
        
        def prepare_insert(obj)
            keys, values = prepare_save(obj)
            value_placeholders = keys.map{'?'}
            sql = "INSERT INTO #{@schema.table} (#{keys.join(',')}) VALUES (#{value_placeholders.join(',')})"
            return [sql, values]
        end
        
        def prepare_update(obj)
            keys, values = prepare_save(obj)
            condition = Condition.new
            @model.primary_keys.each do |key|
                condition[key.name] = obj.get(key)
            end 
            sql = "UPDATE #{@schema.table} SET "
            sql += keys.map{ |key| "#{key} = ?"}.join(',')
            where_sql, where_values = prepare_condition(condition)
            sql += " WHERE #{where_sql}"
            return [sql, values+where_values]
        end
            
        
        # Prepares a value going to be bound to an insert or update statement
        # This method is also called by prepare_condition_value
         def prepare_value(type, value)
             if type.class == Class && type.subclass_of?(Spider::Model::BaseModel)
                 value = type.primary_keys.map{ |key| value.send(key.name) }
             else
                 case type
                 when 'text'
                     #value.gsub!("'", "''")
                     #value = "'#{value}'"
                 when 'dateTime'
                     value = value.strftime("%Y-%m-%d %H:%M:%S")
                 end
                 value = value.to_s
             end
             return @storage.prepare_value(type, value)
         end
         
         def save_associations(obj, element)
             table = @schema.junction_table_name(element.name)
             local_values = {}
             @model.primary_keys.each { |key| local_values[@schema.junction_table_our_field(element.name, key.name)] = obj.get(key) }
             sql = "DELETE FROM #{table} WHERE "
             sql += local_values.map{ |field, val| "#{field} = #{val}"}.join(" AND ")
             #sql += "AND ("+element_values.map{ |field, val| "#{field} <> #{val}"}.join(" OR ")+")"
             @storage.execute(sql)
             obj.get(element).each do |sub_obj|
                 element_values = {}
                 element.model.primary_keys.each { |key| element_values[@schema.junction_table_their_field(element.name, key.name)] = sub_obj.get(key)}
                 element.model.added_elements.each { |added| element_values[@schema.junction_table_added_field(element.name, added.name)] = sub_obj.get(added) if (sub_obj.element_has_value?(added)) }
                 #sql = "SELECT ID FROM #{table} WHERE "
                 #sql += [local_values, element_values].map{ |values| values.map{ |field, val| "#{field} = #{val}"}.join(" AND ") }.join(" AND ")
                 #result = execute(sql)
                 #unless result
                 sql = "INSERT INTO #{table} (#{local_values.keys.join(',')}, #{element_values.keys.join(',')}) VALUES (#{local_values.values.join(',')}, #{element_values.values.join(',')})"
                 @storage.execute(sql)
                 #end
             end
         end
        
        ##############################################################
        #   Loading methods                                          #
        ##############################################################
        
        def fetch(query)
            @model.primary_keys.each do |key|
                query.request[key.name] = true
            end
            sql, values = prepare_select(query)
            result = @storage.execute(sql, values) unless (sql.empty?)
            return result
        end
        
        def integrate(request, result, obj)
            request.keys.each do |element_name|
                element = @model.elements[element_name]
                next if element.model?
                result_value = result[@schema.field(element_name)]
                obj.set_loaded_value(element, prepare_integrate_value(element.type, result_value))
            end
            return obj
        end
        
        def prepare_query(query)
            @model.primary_keys.each do |key|
                query.request[key] = true
            end
            @model.elements.select{ |name, element| !element.model? }.each do |name, element|
                query.request[element] = true
            end
            return query
        end
        
        def prepare_select(query)
            elements = query.request.keys
            keys = []
            elements.each do |el|
                element = @model.elements[el.to_sym]
                if (element.model? && !element.multiple?)
                    keys += element.model.primary_keys.map{ |key| schema.foreign_key_field(el, key.name) }
                elsif (!element.model? && !element.added?)
                    keys << schema.qualified_field(el)
                end
            end
            where_sql, bind_values, joins = prepare_condition(query.condition)
            join_condition = prepare_join(joins)
            tables = ([@schema.table] + joins.map{ |join| join[0] } + joins.map{ |join| join[1] }).flatten.uniq
            condition = where_sql
            condition += " AND (#{join_condition})" unless join_condition.empty?
            order_sql = prepare_order_sql(query)
            return "" if (keys.empty? || where_sql.empty?)
            sql = "SELECT #{keys.join(', ')} FROM #{tables.join(', ')}";
            sql += " WHERE #{condition}"
            sql += " ORDER BY #{order_sql}" unless (order_sql.empty?)
            [sql, bind_values]
        end
        
        def prepare_join(joins)
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
            sql = ""
            h.each_key do |from_table|
                h[from_table].each do |to_table, conditions|
                    conditions.each do |from_key, to_key|
                        sql += " AND " unless sql.empty?
                        sql += "#{from_table}.#{from_key} = #{to_table}.#{to_key}"
                    end
                end
            end
            return sql
        end
        
        
        def prepare_condition(condition)
            p "TOP CONDITION:"
            p condition
            where_sql = ""
            bind_values = []
            joins = []
            condition.each_with_comparision do |k, v, comp|
                where_sql += " #{condition.conjunction} " unless (where_sql.empty?)
                element = @model.elements[k.to_sym]
                if (element.model?)
                    if (!element.multiple? && v.select{ |key, value| !element.model.elements[key].primary_key? }.empty?)
                        # 1/n <-> 1 with only primary keys
                        element_sql = ""
                        v.each_with_comparision do |el_k, el_v, el_comp|
                            element_sql += " AND " unless element_sql.empty?
                            field = schema.foreign_key_field(element.name, el_k)
                            op = comp ? comp : '='
                            element_sql += "#{field} #{op} ?"
                            bind_values << prepare_condition_value(element.model.elements[el_k.to_sym].type, el_v)
                        end
                        where_sql += "(#{element_sql})"
                    else
                        p "IS MODEL!"
                        if (true) # FIXME: check for (element.storage === self)
                            p "PREPARE:"
                            p element.mapper.prepare_condition(v)
                            p "END PREPARE"
                            element_sql, element_values, element_joins = element.mapper.prepare_condition(v)
                            p "ELEMENT JOINS:"
                            p element_joins
                            joins += element_joins
                            joins << get_join(element)
                            where_sql += "(#{element_sql}) "
                            bind_values += element_values
                        else
                            # TODO: add conditions to be checked later
                        end
                    end
                else
                    field = schema.qualified_field(element.name)
                    op = comp ? comp : '='
                    where_sql += "#{field} #{op} ?"
                    p "WHERE SQL NOW IS: #{where_sql}"
                    bind_values << prepare_condition_value(@model.elements[k.to_sym].type, v)
                end
                
            end
            sub_sqls = []
            sub_bind_values = []
            condition.subconditions.each do |sub|
                sub_res = self.prepare_condition(sub)
                p "SUB RES: "
                p sub_res
                sub_sqls << sub_res[0]
                sub_bind_values << sub_res[1]
                joins += sub_res[2]
            end
            sub_where_sql = sub_sqls.join(" #{condition.conjunction} ")
            unless (sub_where_sql.empty?)
                where_sql = "(#{where_sql}) #{condition.conjunction} " unless (where_sql.empty?)
                where_sql += "(#{sub_where_sql})"
                bind_values += sub_bind_values
            end
            return [where_sql, bind_values, joins]
        end
        
        def get_join(element)
            p "GETTING JOIN FOR #{element}"
            return unless element.model?
            element_table = element.mapper.schema.table
            
            if (element.multiple? && element.has_single_reverse?) # 1 <-> n
                p "1<->n"
                #buh
            elsif (element.multiple?) # n <-> n
                p "n<->n"
                #boh
            else # n <-> 1
                keys = {}
                element.model.primary_keys.each do |key|
                    keys[@schema.foreign_key_field(element.name, key.name)] = element.mapper.schema.field(key.name)
                end
                p "OK NOW KEYS:"
                p keys
                join = [schema.table, element.mapper.schema.table, keys]
            end
            return join
        end
        
        def prepare_order_sql(query)
            sql = ''
            query.order.each do |order|
                dir = order[1] ? order[1] : ''
                sql += ', ' unless sql.empty?
                sql += "#{order[0]} #{dir}"
            end
            return sql
        end

        # Prepares a value for an sql condition.
        def prepare_condition_value(type, value)
            return value if ( type.class == Class && type.subclass_of?(Spider::Model::BaseModel) )
            return prepare_value(type, value)
        end

        def prepare_integrate_value(type, value)
            type = type.respond_to?('basic_type') ? type.basic_type : type
            value = value[0] if value.class == Array
            case type
            when 'int'
                return value.to_i
            when 'real'
                return value.to_f
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
            p "GETTING EXTERNAL ELEMENT #{element}"
            element_keys = element.model.primary_keys
            # If the element is not multiple and all requests are primary keys, we already have all we need
            if ( !element.multiple? &&  (query.request.keys - element_keys.map{ |key| key.name }).size == 0 )
                objects.each do |obj|
                    sub_obj = element.model.new()
                    element_keys.each do |key|
                        val = @raw_data[obj.object_id][schema.foreign_key_field(element.name, key.name)]
                        val = element.mapper.prepare_integrate_value(element.model.elements[key.name].type, val)
                        sub_obj.set_loaded_value(key, val)
                        obj.set_loaded_value(element, sub_obj)
                    end
                end
                result = objects
            else
                p "HELLO HERE"
                # FIXME: have to merge the original query?
                sub_query = Query.new
                sub_query.request = query.request || Request.new
                sub_query.condition.conjunction = 'or'
                index_by = []
                if (element.multiple? && !element.has_single_reverse?) # n <-> n
                    p "N2N!!!"
                    element_keys.each { |key| index_by << key }
                    associations = get_associations(element, query, objects)
                    associations.each do |key, rows|
                        rows.each do |row|
                            condition_row = Condition.new
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
                        condition_row = Condition.new
                        if (!element.multiple?) # 1|n <-> 1
                            element_keys.each do |key|
                                condition_row[key.name] = @raw_data[obj.object_id][schema.foreign_key_field(element.name, key.name)]
                            end
                            index_by = element_keys
                        elsif (element.has_single_reverse?) # 1 <-> n
                            sub_request = Request.new
                            @model.primary_keys.each{ |key| sub_request[key.name] = true }
                            sub_query.request[element.attributes[:reverse]] = sub_request
                            @model.primary_keys.each do |key|
                                condition_row["#{element.attributes[:reverse]}.#{key.name}"] = obj.get(key)
                                p "ROW"
                                p condition_row
                            end
                            @model.primary_keys.each{ |key| index_by << "#{element.attributes[:reverse]}.#{key.name}" }
                        end
                        sub_query.condition << condition_row
                    end
                end
                p "SUB QUERY:"
                p sub_query
                element_query_set = QuerySet.new
                element_query_set.index_by(*index_by)
                element_query_set = element.mapper.find(sub_query, element_query_set)
                p "ELEMENT OBJECT SET:"
                p element_query_set
                result = associate_external(element, objects, element_query_set, associations)
            end
            return result
        end
        
        # For each object in an Array or an QuerySet ("objects" param), sets the value of element to the associated
        # objects found in element_query_set
        def associate_external(element, objects, element_query_set, associations=nil)
            print "ASSOCIATING EXTERNAL #{element}"
            primary_keys = @model.primary_keys
            element_keys = element.model.primary_keys
            if (associations) # n <-> n
                objects.each do |obj|
                    obj.set(element, QuerySet.new)
                    obj_key = primary_keys.map{ |key| obj.get(key) }.join(',')
                    obj_associations = associations[obj_key] || []
                    search_params = {}
                    obj_associations.each do |association_row|
                        element_keys.each do |key|
                            search_params[key.name] = association_row[key.name]
                        end
                        sub_obj = element_query_set.find(search_params)[0]
                        element.type.added_elements.each do |added| 
                            sub_obj.set_loaded_value(added, element.mapper.prepare_integrate_value(added.type, association_row[added.name]))
                        end
                        obj.get(element) << sub_obj
                    end
                end 
            elsif (element.multiple? && element.has_single_reverse?) # 1 <-> n"
                p "QUESTO!!!!"
                p "RAW:"
                p @raw_data
                # FIXME: should be already indexed!
                element_query_set.reindex
                objects.each do |obj|
                    search_params = {}
                    @model.primary_keys.each do |key|
                        field = @schema.field(key.name)
                        p "FIELD FOR #{key}: #{field}"
                        p "OBJECT: #{obj.object_id}"
                        search_params["#{element.attributes[:reverse]}.#{key.name}"] = @raw_data[obj.object_id][field]
                    end
                    p "SEARCH PARAMS:"
                    p search_params
                    obj.set_loaded_value(element, element_query_set.find(search_params))
                end
            else # 1|n <-> 1
                objects.each do |obj|
                    search_params = {}
                    element_keys.each do |key|
                        field = schema.foreign_key_field(element.name, key.name)
                        search_params[key.name] = @raw_data[obj.object_id][field]
                    end
                    p "SEARCH PARAMS:"
                    p search_params
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
            request = "SELECT "+primary_keys.map{ |key| @schema.junction_table_our_field(element.name, key.name) }.join(", ")+", "
            request += element_primary_keys.map{ |key| @schema.junction_table_their_field(element.name, key.name) }.join(", ")
            added_elements = element.type.added_elements
            if (added_elements.size > 0)
                request += ', '
                request += added_elements.map{ |added| @schema.junction_table_added_field(element.name, added.name) }.join(", ")
            end
            condition = " WHERE ("+objects.map{ |obj| 
                primary_keys.map{ 
                    |key| @schema.junction_table_our_field(element.name, key.name)+"="+prepare_condition_value( key.type, obj.get(key) ) 
                }.join(" AND ")  
            }.join(") OR (")+")"
            result = @storage.execute(request+" FROM #{x_table} "+condition)
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
                    p "I NEED KEYS FOR #{element.name}"
                    if (element.multiple?)
                        set = obj.send(element.name)
                        set.each do |set_obj|
                            p "1) ADDING DEP #{set_obj} TO #{task.object}"
                            deps << [task, MapperTask.new(set_obj, :keys)]
                        end
                    else
                        p "2) ADDING DEP #{obj.send(element.name)} TO #{task.object}"
                        deps << [task, MapperTask.new(obj.send(element.name), :keys)]
                    end
                end
                elements.select{ |n, el| el.multiple? && el.has_single_reverse? }.each do |name, element|
                    set = obj.send(element.name)
                    set.each do |set_obj|
                        sub_task = MapperTask.new(set_obj, :save)
                        p "3) ADDING DEP #{task.object}_:keys TO #{sub_task.object}_save"
                        deps << [sub_task, MapperTask.new(obj, :keys)]
                    end
                end
            end
            return deps
        end
        
        
        ##############################################################
        #   Schema management                                        #
        ##############################################################

        def schema
            @schema ||= get_schema()
            return @schema
        end
        
        def get_schema()
            schema =  Spider::Model::Storage::Db::DbSchema.new()
            return generate_schema(schema)
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
                            key_column = element.mapper.schema.column(key.name)
                            schema.set_foreign_key(element.name, key.name, 
                                :name => element.storage.column_name("#{element.name}_#{key.name}"),
                                :type => key_column[:type],
                                :attributes => key_column[:attributes]
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
                                :name => @storage.column_name("#{element.type.short_name}_#{key.name}"),
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
            element_prefix = @storage.table_name(element.type.name.sub('::Models', ''))
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
            fields.each_key do |field|
                type = fields[field][:type]
                attributes = fields[field][:attributes]
                attributes ||= {}
                length = attributes[:length]
                sql_fields += ', ' unless sql_fields.empty?
                sql_fields += "#{field} #{type}"
                sql_fields += "(#{length})" if length && length != 0
            end
            @storage.execute("CREATE TABLE #{name} (#{sql_fields})")
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
            fields.each_key do |field|
                type = fields[field][:type]
                attributes = fields[field][:attributes]
                if (current[field])
                    if (type != current[field][:type] || attributes[:length] |= current[field][:length])
                        sql = "ALTER TABLE #{name} ALTER #{field} #{type}"
                        sql += "(#{attributes[:length]})" if attributes[:length]
                        @storage.execute(sql)
                    end
                else
                    sql = "ALTER TABLE #{name} ADD #{field} #{type}"
                    sql += "(#{attributes[:length]})" if attributes[:length]
                    @storage.execute(sql)
                end
            end
            # if (@config[:drop_fields])
            #     current.each_key do |field|
            #         if (!fields[field])
            #             sql = "ALTER TABLE #{name} DROP #{field}"
            #             @storage.execute(sql)
            #         end
            #     end
            # end
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