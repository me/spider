require 'spiderfw/model/mappers/mapper'
require 'fileutils'


module Spider; module Model; module Mappers

    class DbMapper < Spider::Model::Mapper

        def initialize(model, storage)
            super
            @type = :db
        end
        
        def self.write?
            true
        end
        
        def have_references?(element)
            element_name = element.is_a?(Spider::Model::Element) ? element.name : element
            schema.has_foreign_fields?(element_name) || schema.field(element_name)
        end
        
        ##############################################################
        #   Save (insert and update)                                 #
        ##############################################################
        
        def before_save(obj, mode)
            super
        end            
        
        def save_all(root)
            @storage.start_transaction if @storage.supports_transactions?
            super
            @storage.commit
        end
        
        # Inserts passed object into the database
        def do_insert(obj)
            if (obj.model.managed? || !obj.primary_keys_set?)
                assign_primary_keys(obj)
            end
            sql, values = prepare_insert(obj)
            if (sql)
                @storage.execute(sql, *values)
            end
        end
        
        def do_update(obj)
            sql, values = prepare_update(obj)
            if (sql)
                storage.execute(sql, *values)
            end
        end
        
        def do_delete(condition, force=false)
            #delete = prepare_delete(obj)
            del = {}
            del[:condition], del[:joins] = prepare_condition(condition)
            del[:table] = schema.table
            sql, values =  storage.sql_delete(del, force)
            storage.execute(sql, *values)
        end
        
        # def delete_all!
        #     storage.execute("DELETE FROM #{schema.table}")
        # end
        
        def sql_execute(sql, *values)
            storage.execute(sql, *values)
        end
        
        def prepare_save(obj, save_mode, request=nil)
            values = {}
            obj.no_autoload do
                @model.each_element do |element|
                    next if !mapped?(element) || element.integrated?
                    next if save_mode == :update && !obj.element_modified?(element)
                    if (save_mode == :insert && element.attributes[:autoincrement] && !schema.attributes(element.name)[:autoincrement])
                        obj.set(element.name, @storage.sequence_next(schema.sequence(element.name)))
                    end
                    if (!element.multiple?)
                        next if (save_mode == :update && element.primary_key?)
                        next if (element.model? && !schema.has_foreign_fields?(element.name))
                        next if (element.model? && (!(element_val = obj.get(element)) || !obj.get(element).primary_keys_set?))
                        next if (element.integrated?)
                        if (element.model?)
                            element.model.primary_keys.each do |key|
                                # FIXME! only works with one primary key
                                if (key.model?)
                                    key_type = key.model.primary_keys[0].type
                                    key_value = element_val.get(key.name).get(key.model.primary_keys[0])
                                else
                                    key_type = key.model? ? key.model.primary_keys[0].type : key.type
                                    key_value = element_val.get(key.name)
                                end
                                store_key = schema.foreign_key_field(element.name, key.name)
                                values[store_key] = map_save_value(key_type, key_value, save_mode)
                            end
                        else
                            store_key = schema.field(element.name)
                            values[store_key] = map_save_value(element.type, obj.send(element.name), save_mode)
                        end
                    end
                end
            end
            return {
                :values => values
            }
        end
        
        def prepare_insert(obj)
            save = prepare_save(obj, :insert)
            return nil unless save[:values].length > 0
            save[:table] = @schema.table
            return @storage.sql_insert(save)
        end
        
        def prepare_update(obj)
            save = prepare_save(obj, :update)
            return nil unless save[:values].length > 0
            condition = Condition.and
            @model.primary_keys.each do |key|
                condition[key.name] = map_condition_value(key.type, obj.get(key))
            end
            prepare_query_condition(condition)
            save[:condition], save[:joins] = prepare_condition(condition)
            save[:table] = @schema.table
            return @storage.sql_update(save)
        end
        
        def bulk_update(values, condition)
            db_values = {}
            values.each do |key, val|
                element = @model.elements[key]
                next if !mapped?(element) || element.integrated?
                next if element.model?
                store_key = schema.field(element.name)
                next unless store_key
                db_values[store_key] = map_save_value(element.type, val, :update)
            end
            save = {:values => db_values}
            save[:condition], save[:joins] = prepare_condition(condition)
            return @storage.execute(@storage.sql_update(save))
        end
        
        def lock(obj=nil, mode=:exclusive)
            return storage.lock(@schema.table) unless obj
        end 
        
        def sequence_next(name)
            return storage.sequence_next(schema.sequence(name))
        end
        
        ##############################################################
        #   Loading methods                                          #
        ##############################################################
        
        def count(condition)
            q = Query.new(condition, @model.primary_keys)
            prepare_query(q)
            storage_query = prepare_select(q)
            storage_query[:query_type] = :count
            return @storage.query(storage_query)
        end
        
        def fetch(query)
#            Spider.logger.debug("Fetching model #{@model} query:")
#            Spider.logger.debug(query)
            storage_query = prepare_select(query)
            if (storage_query)
                result = @storage.query(storage_query)
                result.total_rows = @storage.total_rows if (query.request.total_rows) 
            end
            return result
        end
        
        def find_by_sql(sql, *bind_vars)
            result = storage.execute(sql, *bind_vars)
            set = QuerySet.new(@model)
            result.each do |row|
                set << map(nil, row, @model)
            end
            return set
        end
        
        def map(request, result, obj)
            if (!request)
                request = Request.new
                @model.elements_array.each{ |el| request.request(el.name) }
            end
            model = obj.is_a?(Class) ? obj : obj.model
            data = {}
            request.keys.each do |element_name|
                element = @model.elements[element_name]
                result_value = nil
                next if !element || element.integrated?
                if (element.model? && schema.has_foreign_fields?(element.name))
                    pks = {}
                    keys_set = true
                    element.model.primary_keys.each do |key| 
                        key_val = result[schema.foreign_key_field(element_name, key.name)]
                        keys_set = false unless key_val
                        pks[key.name] = map_back_value(key.type, key_val)
                    end
#                    begin
                    data[element_name] = keys_set ? Spider::Model.get(element.model, pks) : nil
#                    rescue IdentityMapperException
                        # null keys, nothing to set
#                    end
                elsif !element.model?
                    data[element_name] = map_back_value(element.type, result[schema.field(element_name)])
                end
            end
            begin
                obj = Spider::Model.get(model, data)
            rescue IdentityMapperException => exc
                # This should not happen
                Spider::Logger.warn("Row in DB without primary keys, won't be mapped:")
                Spider::Logger.warn(data)
                return nil
            end
            data.keys.each{ |el| obj.element_loaded(el) }
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
                        polym_obj = polym_obj.mapper.map(polym_request, polym_result, polym_obj)
                        polym_obj.set_loaded_value(model.extended_models[@model], obj)
                        obj = polym_obj
                        break
                    end
                end                    
            end
            return obj
        end

        def prepare_query_request(request, obj=nil)
            super(request, obj)
        end
        
        def can_join?(element)
            return false if element.multiple?
            return false if element.storage != @storage
            return true
        end
        
        def prepare_select(query)
            condition, joins = prepare_condition(query.condition)
            elements = query.request.keys.select{ |k| mapped?(k) }
            keys = []
            types = {}
            if (query.limit && query.order.empty?)
                @model.primary_keys.each do |key|
                    elements << key.name unless elements.include?(key.name)
                    query.order_by(key.name, :asc)
                end
            end
            order, order_joins = prepare_order(query)
            joins += order_joins if order_joins
            elements.each do |el|
                element = @model.elements[el.to_sym]
                next if !element || !element.type || element.integrated?
                if (!element.model?)
                    field = schema.qualified_field(el)
                    keys << field
                    types[field] = map_type(element.type)
                elsif (!element.multiple?)
                    if (schema.has_foreign_fields?(el))
                        element.model.primary_keys.each do |key|
                            field = schema.qualified_foreign_key_field(el, key.name)
                            keys << field
                            types[field]  = map_type(key.type)
                        end
                    end
                    sub_request = query.request[element.name]
                    # if (can_join?(element) && sub_request.is_a?(Request) && 
                    #     sub_request.select{|k, v| !element.model.elements[k].primary_key?}.length > 0)
                    #     sub_request = element.mapper.prepare_query_request(sub_request).reject{ |name, req| element.reverse == name }
                    #     sub_select = element.mapper.prepare_select(Query.new(nil, sub_request))
                    #     keys += sub_select[:keys]
                    #     joins << get_join(element)
                    # end
                end
            end
            if (query.request.polymorphs?)
                only_conditions = {:conj => 'or', :values => []} if (query.request.only_polymorphs?)
                query.request.polymorphs.each do |model, polym_request|
                    extension_element = model.extended_models[@model]
                    model.mapper.prepare_query_request(polym_request)
                    polym_request.reject!{|k, v| 
                        model.elements[k].integrated? && model.elements[k].integrated_from.name == extension_element
                    }
                    polym_only = {:conj => 'and', :values => []} if (query.request.only_polymorphs?)
                    model.elements_array.select{ |el| el.attributes[:local_pk] }.each do |el|
                        polym_request[el.name] = true
                        if (query.request.only_polymorphs?)
                            polym_only[:values] << [model.mapper.schema.qualified_field(el.name), '<>', nil]
                        end
                    end
                    only_conditions[:values] << polym_only if query.request.only_polymorphs?
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
                    join = {
                        :type => :left_outer,
                        :from => @schema.table,
                        :to => model.mapper.schema.table,
                        :keys => join_fields
                    }
                    joins << join
                end

            end
            if (only_conditions)
                if (condition[:conj].downcase != 'and')
                    condition = {:conj => 'and', :values => [condition]}
                end
                condition[:values] << only_conditions
            end
            tables = [schema.table]
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
                cur = (h[join[:from]][join[:to]] ||= [])
                has_join = false
                cur.each do |cur_join|
                    if (cur_join[:keys] == join[:keys] && cur_join[:conditions] == join[:conditions])
                        has_join = true
                        break
                    end
                end
                h[join[:from]][join[:to]] << join unless has_join
            end
            return h
        end
        
        
        def prepare_condition(condition)
            # FIXME: move to mapper
            model = condition.polymorph ? condition.polymorph : @model
            model_schema = model.mapper.schema
            # debugger if condition.polymorph
            condition.each_with_comparison do |k, v, comp|
                # normalize condition values
                element = model.elements[k.to_sym]
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
                element = model.elements[k.to_sym]
                next unless model.mapper.mapped?(element)
                if (element.model?)
                    if (!element.multiple? && v.select{ |key, value| !element.model.elements[key].primary_key? }.empty?)
                        # 1/n <-> 1 with only primary keys
                        element_cond = {:conj => 'AND', :values => []}
                        v.each_with_comparison do |el_k, el_v, el_comp|
                            field = model_schema.qualified_foreign_key_field(element.name, el_k)
                            op = comp ? comp : '='
                            field_cond = [field, op,  map_condition_value(element.model.elements[el_k.to_sym].type, el_v)]
                            element_cond[:values] << field_cond
                        end
                        cond[:values] << element_cond
                    else
                        if (element.storage == model.mapper.storage)
                            element.mapper.prepare_query_condition(v)
                            element_condition, element_joins = element.mapper.prepare_condition(v)
                            joins += element_joins
                            joins << model.mapper.get_join(element)
                            cond[:values] << element_condition
                        else
                           remaining_condition ||= Condition.new
                           remaining_condition.set(k, comp, v)
                        end
                    end
                elsif(model_schema.field(element.name))
                    field = model_schema.qualified_field(element.name)
                    op = comp ? comp : '='
                    cond[:values] << [field, op, map_condition_value(model.elements[k.to_sym].type, v)]
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
            Spider::Logger.debug("Getting join for model #{@model} to element #{element}")
            Spider::Logger.debug(@model.primary_keys.map{|k| k.name})
            element_table = element.mapper.schema.table
            if (schema.has_foreign_fields?(element.name))
                Spider::Logger.debug("JOIN A")
                keys = {}
                element.model.primary_keys.each do |key|
                    if (key.integrated?)
                        # FIXME
                        raise "Unimplemented join dereference for multiple primary keys" if key.integrated_from.model.primary_keys.length > 1
                        el_field = element.mapper.schema.foreign_key_field(key.integrated_from.name, key.integrated_from.model.primary_keys[0].name)
                    else
                        el_field = element.mapper.schema.field(key.name)
                    end
                    keys[schema.foreign_key_field(element.name, key.name)] = el_field
                    # FIXME: works with models as primary keys through a hack in the field method of db_schema,
                    # assuming the model has only one key. the correct way would be to get another join
                end
                if (element.condition)
                    condition, condition_joins, condition_remaining = element.mapper.prepare_condition(element.condition)
                end
                join = {
                    :type => :inner,
                    :from => schema.table,
                    :to => element.mapper.schema.table,
                    :keys => keys,
                    :condition => condition
                }
            elsif (element.has_single_reverse? && element.mapper.schema.has_foreign_fields?(element.reverse)) # n/1 <-> n
                Spider::Logger.debug("JOIN B")
                keys = {}
                @model.primary_keys.each do |key|
                    our_field = nil
                    if (key.integrated?)
                        our_field = schema.foreign_key_field(key.integrated_from.name, key.integrated_from_element)
                    else
                        our_field = schema.field(key.name)
                    end
                    keys[our_field] = element.mapper.schema.foreign_key_field(element.reverse, key.name)
                end
                if (element.condition)
                    condition, condition_joins, condition_remaining = element.mapper.prepare_condition(element.condition)
                end
                join = {
                    :type => :inner,
                    :from => schema.table,
                    :to => element.mapper.schema.table,
                    :keys => keys,
                    :condition => condition
                }
                #buh
            else # n <-> n
                #boh
            end
            # FIXME: add element conditions!
            return join
        end
        
        def get_deep_join(dotted_element)
            #return [[], @model, @model.elements[dotted_element]] unless dotted_element.is_a?(String)
            parts = dotted_element.to_s.split('.').map{ |el| el.to_sym }
            current_model = @model
            joins = []
            el = nil
            parts.each do |part|
                el = current_model.elements[part]
                if (el.integrated?)
                    joins << current_model.mapper.get_join(el.integrated_from)
                    current_model = el.integrated_from.type
                    el = current_model.elements[el.integrated_from_element]
                end
                if (el.model?) # && can_join?(el)
                    joins << current_model.mapper.get_join(el)
                    current_model = el.model
                end
            end
            while (el.integrated?)
                joins << current_model.mapper.get_join(el.integrated_from)
#                joins << current_model.integrated_from.mapper.get_join(el.integrated_from_element)
                current_model = el.integrated_from.type
                el = current_model.elements[el.integrated_from_element]
            end
            return [joins, current_model, el]
        end
        
        def prepare_order(query)
            joins = []
            fields = []
            query.order.each do |order|
                order_element, direction = order
                el_model = @model
                if (order_element.is_a?(QueryFuncs::Function))
                    func_fields = []
                    func_elements = order_element.inner_elements
                    func_elements.each do |el_name, owner_func|
                        el_joins, el_model, el = get_deep_join(el_name)
                        joins += el_joins
                        owner_func.mapper_fields ||= {}
                        owner_func.mapper_fields[el.name] = el_model.mapper.schema.qualified_field(el.name)
                    end
                    field = storage.function(order_element)
                else
                    el_joins, el_model, el = get_deep_join(order_element)
                    field = el_model.mapper.schema.qualified_field(el.name)
                    joins += el_joins
                end
                fields << [field, direction]
            end
            return [fields, joins]
        end

        
        def map_type(type)
            st = type
            while (st && !storage.class.base_types.include?(st))
                st = Model.simplify_type(st)
            end
            return type unless st
            return st
        end
        
        def map_value(type, value, mode=nil)
             if (type.subclass_of?(Spider::DataType) && value)
                 value = type.new(value) unless value.is_a?(type)
                 value = value.map(self.type)
             elsif type.class == Class && type.subclass_of?(Spider::Model::BaseModel)
                 value = type.primary_keys.map{ |key| value.send(key.name) }
             else
                 case type.name
                 when 'Spider::DataTypes::Bool'
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
            if value.is_a?(Range)
                return Range.new(map_condition_value(type, value.first), map_condition_value(type, value.last))
            end
            return value if ( type.class == Class && type.subclass_of?(Spider::Model::BaseModel) )
            value = map_value(type, value, :condition)
            return @storage.value_for_condition(type, value)
        end

        def map_back_value(type, value)
            type = type.respond_to?('basic_type') ? type.basic_type : type
            value = value[0] if value.class == Array
            value = storage.value_to_mapper(type, value)
            case type.name
            when 'Fixnum'
                return value ? value.to_i : nil
            when 'Float'
                return value ? value.to_f : nil
            when 'Spider::DataTypes::Bool'
                return value == 1 ? true : false
            end
            return nil unless value
            case type.name
            when 'DateTime'
                return DateTime.parse(value) unless value.is_a?(Date)
            end
            return value
        end
        
        ##############################################################
        #   External elements                                        #
        ##############################################################
        
        def associate_external(element, objects, result)
            result.reindex
            objects.element_loaded(element.name)
            objects.each_current do |obj|
                search_params = {}
                @model.primary_keys.each do |key|
                    field = @schema.field(key.name)
                    search_params[:"#{element.attributes[:reverse]}.#{key.name}"] = obj.get(key) #@raw_data[obj.object_id][field] # FIXME: right or wrong?
                end
                sub_res = result.find(search_params)
                sub_res.each do |sub_obj|
                    sub_obj.set_loaded_value(element.attributes[:reverse], obj)
                end
                sub_res = sub_res[0] if !element.multiple?
                obj.set_loaded_value(element, sub_res)
            end
            return objects
        end
        
        
        ##############################################################
        #   Primary keys                                             #
        ##############################################################
        
        def assign_primary_keys(obj)
            # may be implemented in model through the 'with_mapper' method
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
                deps << [task, MapperTask.new(obj, :save)] unless obj.primary_keys_set? || (!obj.mapper || !obj.mapper.class.write?)
            when :save
                elements = @model.elements.select{ |n, el| el.model? && obj.element_has_value?(el) && obj.element_modified?(el)}
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
                    if (element.model? && element.type.mapper && element.type.mapper.class.write?)
                        set = obj.send(element.name)
                        set.each do |set_obj|
                            sub_task = MapperTask.new(set_obj, :save)
                            deps << [sub_task, MapperTask.new(obj, :keys)]
                        end
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
        
        def get_schema
            return @model.superclass.mapper.get_schema() if (@model.attributes[:inherit_storage])
            if (@schema_define_proc)
                schema =  Spider::Model::Storage::Db::DbSchema.new
                schema.instance_eval(&@schema_define_proc)
                schema = generate_schema(schema)
            else
                schema = generate_schema
            end
            if (@schema_proc)
                schema.instance_eval(&@schema_proc)
            end
            return schema
        end

        def generate_schema(schema=nil)
            had_schema = schema ? true : false
            schema ||= Spider::Model::Storage::Db::DbSchema.new
            n = @model.name.sub('::Models', '')
            n.sub!(@model.app.name, @model.app.short_prefix) if @model.app.short_prefix
            schema.table ||= @storage.table_name(n)
            primary_key_columns = []
            integrated_pks = []
            @model.each_element do |element|
                if element.integrated?
                    integrated_pks << [element.integrated_from.name, element.integrated_from_element] if (element.primary_key?)
                end
            end
            @model.each_element do |element|
                next if element.integrated?
                next unless mapped?(element)
                next if had_schema && schema.pass[element.name]
                next if element.attributes[:added_reverse] && element.has_single_reverse?
                if (!element.model?)
                    type = element.custom_type? ? element.type.class.maps_to : element.type
                    current_column = schema.columns[element.name] || {}
                    storage_type = type
                    while (!@storage.class.base_types.include?(storage_type))
                        storage_type = Model.simplify_type(storage_type)
                    end
                    db_attributes = current_column[:attributes]
                    if (!db_attributes)
                        db_attributes = @storage.column_attributes(storage_type, element.attributes)
                        db_attributes.merge(element.attributes[:db]) if (element.attributes[:db]) 
                        if (element.attributes[:autoincrement] && !db_attributes[:autoincrement])
                            schema.set_sequence(element.name, @storage.sequence_name("#{schema.table}_#{element.name}"))
                        end
                    end
                    column_name = current_column[:name] || @storage.column_name(element.name)
                    column_type = current_column[:type] || @storage.column_type(storage_type, element.attributes)
                    schema.set_column(element.name,
                        :name => column_name,
                        :type => column_type,
                        :attributes => db_attributes
                    )
                    primary_key_columns << column_name if element.primary_key?
                elsif (true) # FIXME: must have condition element.storage == @storage in some of the subcases
                    if (!element.multiple?) # 1/n <-> 1
                        current_schema = schema.foreign_keys[element.name] || {}
                        element.type.primary_keys.each do |key|
                            if key.model? # fixme: only works with single primary key model (after the first)
                                curr_key = key
                                curr_key = curr_key.model.primary_keys[0] while curr_key.model? && curr_key.model.primary_keys.length == 1
                                next if curr_key.model
                                key_type = curr_key.type
                                key_attributes = curr_key.attributes
                            else
                                key_type = key.type
                                key_attributes = key.attributes
                            end
                            #key_column = element.mapper.schema.column(key.name)
                            
                            key_attributes = {
                                :length => key_attributes[:length],
                                :precision => key_attributes[:precision]
                            }
                            current = current_schema[key.name] || {}
                            column_name = current[:name] || @storage.column_name("#{element.name}_#{key.name}")
                            column_type = current[:type] || @storage.column_type(key_type, key_attributes)
                            column_attributes = current[:attributes] || @storage.column_attributes(key_type, key_attributes)
                            schema.set_foreign_key(element.name, key.name, 
                                :name => column_name,
                                :type => column_type,
                                :attributes => column_attributes
                            )
                            if (element.primary_key? || integrated_pks.include?([element.name, key.name]))
                                primary_key_columns << column_name
                            end
                        end
                    end
                end
            end
            schema.set_primary_key(primary_key_columns) if primary_key_columns.length > 0
            @model.sequences.each do |name|
                schema.set_sequence(name, @storage.sequence_name("#{schema.table}_#{name}"))
            end
            return schema
        end
        
        def collect_real_keys(element, path=[])
            real_keys = []
            element.type.primary_keys.each do |key|
                if (key.model?)
                    real_keys += schema_collect_real_keys(key, path<<element.name)
                else
                    real_keys << [key, path<<element.name]
                end
            end
            return real_keys
        end

        def sync_schema(force=false, options={})
            schema_description = schema.get_schemas
            sequences = schema.sequences.values

            @model.elements_array.select{ |el| el.attributes[:anonymous_model] }.each do |el|
                next if el.model.mapper.class != self.class
                schema_description.merge!(el.model.mapper.schema.get_schemas)
                sequences += el.model.mapper.schema.sequences.values
                # Spider::Logger.debug("MERGING SEQUENCES:")
                # Spider::Logger.debug(el.model.mapper.schema.sequences)
                # sequences.merge!(el.model.mapper.schema.sequences)
            end
            schema_description.each do |table_name, table_schema|
                table_attributes = {:primary_key => table_schema[:attributes][:primary_key]}
                if @storage.table_exists?(table_name)
                    alter_table(table_name, table_schema[:columns], table_attributes, force)
                else
                    create_table(table_name, table_schema[:columns], table_attributes)
                end
                if (options[:drop_fields])
                    current = @storage.describe_table(table_name)[:columns]
                    current.each_key do |cur|
                        @storage.drop_field(table_name, cur) if (!table_schema[:columns][cur])
                    end
                end
            end
            seen = {}
            schema.sequences.each do |element_name, db_name|
                next if seen[db_name]
                if storage.sequence_exists?(db_name)
                    sql = "SELECT MAX(#{schema.field(element_name)}) AS M FROM #{schema.table}"
                    res = @storage.execute(sql)
                    max = res[0]['M'].to_i
                    storage.update_sequence(db_name, max)
                else
                    storage.create_sequence(db_name)
                end
                seen[db_name] = true
            end
        end

        def create_table(table_name, fields, attributes)
            fields = fields.map{ |name, details| {
              :name => name,
              :type => details[:type],
              :attributes => details[:attributes]  
            } }
            @storage.create_table({
                :table => table_name,
                :fields => fields,
                :attributes => attributes,
            })
        end

        def alter_table(name, fields, attributes, force=nil)
            current = @storage.describe_table(name)
            current_fields = current[:columns]
            add_fields = []
            alter_fields = []
            all_fields = []
            unsafe = []
            fields.each_key do |field|
                field_hash = {
                    :name => field, 
                    :type => fields[field][:type], 
                    :attributes => fields[field][:attributes]
                }
                all_fields << field_hash
                if (!current_fields[field])
                    add_fields << field_hash
                else
                    type = fields[field][:type]
                    attributes = fields[field][:attributes]
                    attributes ||= {}
                    if (!@storage.schema_field_equal?(current_fields[field], fields[field]))
                        Spider.logger.debug("DIFFERENT: #{field}")
                        Spider.logger.debug(current_fields[field])
                        Spider.logger.debug(fields[field])
                        unless @storage.safe_schema_conversion?(current_fields[field], fields[field]) || force
                            unsafe << field 
                        end
                        alter_fields << field_hash
                    end
                end
                raise SchemaSyncUnsafeConversion.new(unsafe) unless unsafe.empty?
            end
            alter_attributes = {}
            if (current[:primary_key] != attributes[:primary_key])
                alter_attributes[:primary_key] = attributes[:primary_key]
            end
            @storage.alter_table({
                :table => name,
                :add_fields => add_fields,
                :alter_fields => alter_fields,
                :all_fields => all_fields,
                :attributes => alter_attributes
            })
        end

    end

    class SchemaSyncUnsafeConversion < RuntimeError
        attr :fields
        def initialize(fields)
            @fields = fields
        end
        def to_s
            "Unsafe conversion on fields #{fields.join(', ')}"
        end
    end

end; end; end
