require 'spiderfw/model/mappers/mapper'
require 'fileutils'


module Spider; module Model; module Mappers

    class DbMapper < Spider::Model::Mapper

        def initialize(model, storage)
            super
        end
        
        def have_references?(element)
            element_name = element.is_a?(Spider::Model::Element) ? element.name : element
            schema.has_foreign_fields?(element_name) || schema.field(element_name)
        end
        
        ##############################################################
        #   Save (insert and update)                                 #
        ##############################################################
        
        def before_save(obj)
            @model.elements.select{ |n, el| 
                mapped?(el) && obj.element_has_value?(el) && el.has_single_reverse? 
            }.each do |name, element|
                # FIXME: what is this?!?
                # if (element.multiple?)
                #     obj.send(name).each { |o| o.send("#{element.attributes[:reverse]}=", obj) }
                # else
                #     obj.send(name).send("#{element.attributes[:reverse]}=", obj)
                # end
            end
            super(obj)
        end
        
        def after_save(obj)
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
            if (sql)
                @storage.execute(sql, *values)
                if (delayed_primary_keys?)
                    @model.primary_keys.each do |key|
                        obj.set_loaded_value(key, @storage.assigned_key(key))
                    end
                end
                @storage.commit
            end
        end
        
        def do_update(obj)
            @storage.start_transaction if @storage.supports_transactions?
            sql, values = prepare_update(obj)
            if (sql)
                @storage.execute(sql, *values)
                @storage.commit
            end
        end
        
        def do_delete(condition)
            #delete = prepare_delete(obj)
            del = {}
            del[:condition], del[:joins] = prepare_condition(condition)
            del[:table] = @schema.table
            sql, values =  @storage.sql_delete(del)
            @storage.execute(sql, *values)
        end
        
        def sql_execute(sql, *values)
            @storage.execute(sql, *values)
        end
        
        def prepare_save(obj, save_mode, request=nil)
            values = {}
            @model.each_element do |element|
                next if !mapped?(element) || element.integrated?
                next if save_mode == :update && !obj.element_modified?(element)
                if (save_mode == :insert && element.attributes[:autoincrement] && !@storage.supports?(:autoincrement))
                    obj.set(element.name, @storage.sequence_next(schema.table, schema.field(element.name)))
                end
                if (!element.multiple?)
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
         
        
        ##############################################################
        #   Loading methods                                          #
        ##############################################################
        
        def count(condition)
            storage_query = prepare_select(query)
            storage_query[:type] = :count
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
        
        def map(request, result, obj)
            model = obj.is_a?(Class) ? obj : obj.class
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
                        pks[key.name] = key_val
                    end
#                    begin
                    data[element_name] = Spider::Model.get(element.model, pks) if keys_set
#                    rescue IdentityMapperException
                        # null keys, nothing to set
#                    end
                elsif !element.model?
                    data[element_name] = map_back_value(element.type, result[schema.field(element_name)])
                end
            end
            # Spider::Logger.debug("GETting #{model}")
            # Spider::Logger.debug(data)
            obj = Spider::Model.get(model, data)
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
                    query.order << [key.name, 'asc']
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
            tables = [@schema.table]
            
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
                        element_cond = {:conj => 'AND', :values => []}
                        v.each_with_comparison do |el_k, el_v, el_comp|
                            field = schema.qualified_foreign_key_field(element.name, el_k)
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
            if (schema.has_foreign_fields?(element.name))
                keys = {}
                element.model.primary_keys.each do |key|
                    keys[schema.foreign_key_field(element.name, key.name)] = element.mapper.schema.field(key.name)
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
        
        def prepare_order(query)
            joins = []
            fields = []
            query.order.each do |order|
                element_name, direction = order
                parts = element_name.to_s.split('.')
                current_model = @model
                parts.each do |part|
                    el = current_model.elements[part.to_sym]
                    if (el.model? && current_model.mapper.can_join?(el))
                        joins << get_join(el.name)
                        current_model = el.model
                    elsif (field = current_model.mapper.schema.qualified_field(el.name))
                        fields << [field, direction]
                    end
                end
            end
            return [fields, joins]
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
             objects.each do |obj|
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
                    end
                end
            end
            return schema
        end

        def sync_schema(force=false)
            schema_description = schema.get_schemas
            @model.elements_array.select{ |el| el.attributes[:anonymous_model] }.each do |el|
                schema_description.merge!(el.model.mapper.schema.get_schemas)
            end
            schema_description.each do |table_name, table_schema|
                if @storage.table_exists?(table_name)
                    alter_table(table_name, table_schema, force)
                else
                    create_table(table_name, table_schema)
                end
            end
            schema.sequences.each do |name|
                create_sequence(name) unless sequence_exists?(name)
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
