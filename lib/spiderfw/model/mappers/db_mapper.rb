require 'spiderfw/model/mappers/mapper'
require 'fileutils'


module Spider; module Model; module Mappers

    class DbMapper < Spider::Model::Mapper
        include Spider::Model::Storage::Db

        def initialize(model, storage)
            super
            @type = :db
        end
        
        def self.write? #:nodoc:
            true
        end
        
        def pk
            [Fixnum, {:autoincrement => true}]
        end
        
        # Checks if the schema has some key to reach element. 
        def have_references?(element) #:nodoc:
            element = @model.elements[element] unless element.is_a?(Element)
            schema.has_foreign_fields?(element.name) || schema.field(element.name)
        end
        
        def someone_have_references?(element)
            element = @model.elements[element] unless element.is_a?(Element)
            if (element.integrated?)
                return element.model.someone_have_references?(element.attributes[:integrated_from_element])
            end
            return have_references?(element)
        end
        
        ##############################################################
        #   Save (insert and update)                                 #
        ##############################################################
        
        def before_save(obj, mode) #:nodoc:
            super
        end            
        
        
        def do_insert(obj) #:nodoc:
            if (obj.model.managed? || !obj.primary_keys_set?)
                assign_primary_keys(obj)
            end
            sql, values = prepare_insert(obj)
            if (sql)
                @storage.execute(sql, *values)
            end
        end
        
        def do_update(obj) #:nodoc:
            sql, values = prepare_update(obj)
            if (sql)
                storage.execute(sql, *values)
            end
        end
        
        def do_delete(condition, force=false) #:nodoc:
            #delete = prepare_delete(obj)
            del = {}
            del[:condition], del[:joins] = prepare_condition(condition)
            del[:table] = schema.table
            sql, values =  storage.sql_delete(del, force)
            storage.execute(sql, *values)
        end
        
        def truncate!
            sql = storage.sql_truncate(schema.table)
            storage.execute(sql)
        end
        
        # def delete_all!
        #     storage.execute("DELETE FROM #{schema.table}")
        # end
        
        # Execute SQL directly, returning raw db results.
        def sql_execute(sql, *values)
            storage.execute(sql, *values)
        end
        
        # Save preprocessing
        def prepare_save(obj, save_mode) #:nodoc:
            values = {}
            obj.no_autoload do
                @model.each_element do |element|
                    next if !mapped?(element) || element.integrated?
                    next if save_mode == :update && !obj.element_modified?(element)
                    if (save_mode == :insert)
                        if element.attributes[:autoincrement] && !schema.attributes(element.name)[:autoincrement]
                            obj.set(element.name, @storage.sequence_next(schema.sequence(element.name)))
                        end
                    end
                    if (!element.multiple?)
                        next if (save_mode == :update && element.primary_key?)
                        next if (element.model? && !schema.has_foreign_fields?(element.name))
                        element_val = obj.get(element)
                        # next if (element.model? && (!(element_val = obj.get(element)) || !))
                        next if (element.integrated?)
                        element_val = nil if element.model? && element_val.is_a?(BaseModel) && !element_val.primary_keys_set?
                        if (element.model?)
                            element.model.primary_keys.each do |key|
                                # FIXME! only works with one primary key
                                if (key.model?)
                                    key_type = key.model.primary_keys[0].type
                                    key_value = element_val ? element_val.get(key.name).get(key.model.primary_keys[0]) : nil
                                else
                                    key_type = key.model? ? key.model.primary_keys[0].type : key.type
                                    key_value = element_val ? element_val.get(key.name) : nil
                                end
                                store_key = schema.foreign_key_field(element.name, key.name)
                                next if store_key.is_a?(FieldExpression)
                                values[store_key] = map_save_value(key_type, key_value, save_mode)
                            end
                        else
                            store_key = schema.field(element.name)
                            values[store_key] = map_save_value(element.type, element_val, save_mode)
                        end
                    end
                end
            end
            return {
                :values => values
            }
        end
        
        # Insert preprocessing
        def prepare_insert(obj) #:nodoc:
            save = prepare_save(obj, :insert)
            return nil unless save[:values].length > 0
            save[:table] = @schema.table
            return @storage.sql_insert(save)
        end
        
        # Update preprocessing
        def prepare_update(obj) #:nodoc:
            save = prepare_save(obj, :update)
            return nil unless save[:values].length > 0
            condition = Condition.and
            @model.primary_keys.each do |key|
                condition[key.name] = obj.get(key)
            end
            preprocess_condition(condition)
            save[:condition], save[:joins] = prepare_condition(condition)
            save[:joins] = prepare_joins(save[:joins])
            save[:table] = @schema.table
            return @storage.sql_update(save)
        end
        
        # Updates according to a condition, storing the values, which must passed as a Hash.
        def bulk_update(values, condition)
            db_values = {}
            joins = []
            integrated = {}
            condition = preprocess_condition(condition)
            values.each do |key, val|
                element = @model.elements[key]
                if (element.integrated?)
                    integrated[element.integrated_from] ||= {}
                    integrated[element.integrated_from][key] = val
                    next
                end
                next if !mapped?(element)
                next if element.model? && val != nil
                store_key = schema.field(element.name)
                next unless store_key
                if (val.is_a?(Spider::QueryFuncs::Expression))
                    joins += prepare_expression(val)
                    db_values[store_key] = val
                else
                    db_values[store_key] = map_save_value(element.type, val, :update)
                end
            end
            integrated.each do |i_el, i_values|
                next unless condition[i_el.name]
                i_el.mapper.bulk_update(i_values, condition[i_el.name]) # FIXME?
            end
            return if db_values.empty?
            save = {:table => schema.table, :values => db_values}
            condition, c_joins = prepare_condition(condition)
            joins += c_joins
            save[:condition] = condition
            save[:joins] = prepare_joins(joins)
            sql, bind_vars = @storage.sql_update(save)
            return @storage.execute(sql, *bind_vars)
        end
        
        # Lock db
        #--
        # FIXME
        def lock(obj=nil, mode=:exclusive) #:nodoc:
            return storage.lock(@schema.table) unless obj
        end 
        
        # Next value for the named sequence
        def sequence_next(name)
            return storage.sequence_next(schema.sequence(name))
        end
        
        ##############################################################
        #   Loading methods                                          #
        ##############################################################
        
        # Implements the Mapper#count method doing a count SQL query.
        def count(condition_or_query)
            if (condition_or_query.is_a?(Query))
                q = condition_or_query.clone
            else
                q = Query.new(condition_or_query, @model.primary_keys) 
            end
            prepare_query(q)
            storage_query = prepare_select(q)
            storage_query[:query_type] = :count
            storage_query.delete(:order)
            storage_query.delete(:limit)
            return @storage.query(storage_query)
        end
        
        # Implements the Mapper#fetch method.
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
        
        # Finds objects by SQL, mapping back the storage result.
        def find_by_sql(sql, *bind_vars)
            result = storage.execute(sql, *bind_vars)
            set = QuerySet.new(@model)
            result.each do |row|
                set << map(nil, row, @model)
            end
            set.modified = false
            return set
        end
        
        # Implements the Mapper#map method.
        # Converts a DB result row to an object.
        def map(request, result, obj_or_model)
            if (!request || request == true)
                request = Request.new
                @model.elements_array.each{ |el| request.request(el.name) }
            end
            model = obj_or_model.is_a?(Class) ? obj_or_model : obj_or_model.model
            data = {}
            request.keys.each do |element_name|
                element = @model.elements[element_name]
                result_value = nil
                next if !element || element.integrated? || !have_references?(element)
                if (element.model? && schema.has_foreign_fields?(element.name))
                    pks = {}
                    keys_set = true
                    element.model.primary_keys.each do |key| 
                        key_val = result[schema.foreign_key_field(element_name, key.name).name]
                        keys_set = false unless key_val
                        pks[key.name] = map_back_value(key.type, key_val)
                    end
#                    begin
                    data[element_name] = keys_set ? Spider::Model.get(element.model, pks, true) : nil
#                    rescue IdentityMapperException
                        # null keys, nothing to set
#                    end
                elsif !element.model?
                    data[element_name] = map_back_value(element.type, result[schema.field(element_name).name])
                end
            end
            begin
                obj = Spider::Model.get(model, data, true)
            rescue IdentityMapperException => exc
                # This should not happen
                Spider::Logger.warn("Row in DB without primary keys for model #{model}; won't be mapped:")
                Spider::Logger.warn(data)
                return nil
            end
            data.keys.each{ |el| obj.element_loaded(el) }
            if (request.polymorphs)
                request.polymorphs.each do |model, polym_request|
                    polym_result = {}
                    polym_request.keys.each do |element_name|
                        field = model.mapper.schema.field(element_name).name
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

        def prepare_query_request(request, obj=nil) #:nodoc:
            super(request, obj)
        end
        
        # Returns true if an element can be loaded joined-in.
        def can_join?(element)
            return false if element.storage != @storage
            return true
        end
        
        # Generates a select hash description based on the query.
        def prepare_select(query) #:nodoc:
            condition, joins = prepare_condition(query.condition)
            elements = query.request.keys.select{ |k| mapped?(k) }
            keys = []
            primary_keys = []
            types = {}
            if (query.limit && query.order.empty? && !query.only_one?)
                @model.primary_keys.each do |key|
                    elements << key.name unless elements.include?(key.name)
                    query.order_by(key.name, :asc)
                end
            end
            order, order_joins = prepare_order(query)
            cnt = 0
            order_joins.each do |oj|
                oj[:as] ||= "ORD#{cnt+=1}" if joins.select{ |j| j[:to] == oj[:to] }.length > 0
            end
            joins += order_joins if order_joins
            seen_fields = {}
            model_pks = []
            @model.primary_keys.each do |pk|
                if (pk.integrated?)
                    model_pks << pk.integrated_from.name
                else
                    model_pks << pk.name
                end
            end
            elements.each do |el|
                element = @model.elements[el.to_sym]
                next if !element || !element.type || element.integrated?
                if !element.model?
                    field = schema.field(el)
                    primary_keys << field if model_pks.include?(el)
                    unless seen_fields[field.name]
                        keys << field
                        seen_fields[field.name] = true
                    end
                elsif !element.attributes[:junction]
                    if schema.has_foreign_fields?(el)
                        element.model.primary_keys.each do |key|
                            field = schema.foreign_key_field(el, key.name)
                            raise "Can't find a foreign key field for key #{key.name} of element #{el} of model #{@model}" unless field
                            primary_keys << field if model_pks.include?(el)
                            unless seen_fields[field.name]
                                keys << field
                                seen_fields[field.name] = true
                            end
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
            if (query.request.polymorphs? || !query.condition.polymorphs.empty?)
                only_conditions = {:conj => 'or', :values => []} if (query.request.only_polymorphs?)
                polymorphs = (query.request.polymorphs.keys + query.condition.polymorphs).uniq
                polymorphs.each do |model|
                    polym_request = query.request.polymorphs[model] || Request.new
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
                    polym_select[:keys].map!{ |key| "#{key} AS #{key.to_s.gsub('.', '_')}"}
                    keys += polym_select[:keys]
                    join_fields = {}
                    @model.primary_keys.each do |key|
                        from_field = @schema.field(key.name)
                        to_field = model.mapper.schema.foreign_key_field(extension_element, key.name)
                        join_fields[from_field] = to_field 
                    end
                    # FIXME: move to get_join
                    join = {
                        :type => :left,
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
                :primary_keys => primary_keys.uniq,
                :tables => tables,
                :condition => condition,
                :joins => joins,
                :order => order,
                :offset => query.offset,
                :limit => query.limit
            }
        end
        
        #--
        # FIXME: document
        def prepare_joins(joins) # :nodoc:
            h = {}
            left_joins = []
            joins.each do |join|
                h[join[:from]] ||= {}
                cur = (h[join[:from]][join[:to]] ||= [])
                has_join = false
                cur.each do |cur_join|
                    if (cur_join[:keys] == join[:keys] && cur_join[:conditions] == join[:conditions])
                        cur_join[:type] = :left if join[:type] == :left
                        has_join = true
                        break
                    end
                end
                left_joins << join if join[:type] == :left
                h[join[:from]][join[:to]] << join unless has_join
            end
            while left_joins.length > 0
                new_left_joins = []
                left_joins.each do |lj|
                    if h[lj[:to]]
                        h[lj[:to]].each_key do |to|
                            h[lj[:to]][to].each do |j|
                                unless j[:type] == :left
                                    new_left_joins << j
                                    j[:type] = :left
                                end
                            end
                        end
                    end
                end
                left_joins = new_left_joins
            end
            return h
        end
        
        
        # Generates a storage description for the condition
        # Returns a list of three elements, composed of
        # * conditions: an hash 
        #     {
        #       :conj => 'and'|'or',
        #       :values => an array of [field, comparison, value] triplets
        #     }
        # * joins: an array of structures as returned by #get_join
        # * remaining_condition: part of the condition which can't be passed to the storage
        #--
        # TODO: better name for :values
        def prepare_condition(condition, options={})
            model = condition.polymorph ? condition.polymorph : @model
            model_schema = model.mapper.schema
            cond = {}

            bind_values = []
            joins = options[:joins] || []
            remaining_condition = Condition.new # TODO: implement
            cond[:conj] = condition.conjunction.to_s
            cond[:values] = []
            

            # Returns an hash of elements that need an "inner" join
            def get_join_info(model, condition)
                join_info = {}
                condition.each_with_comparison do |k, v, comp|
                    next unless k.respond_to?(:to_sym)
                    element = model.elements[k.to_sym]
                    next unless element
                    next unless model.mapper.mapped?(element)
                    next unless element.model?
                    join_info[k.to_s] = if v.nil?
                        comp == '<>' ? true : false
                    else
                        comp == '<>' ? false : true
                    end
                    if v.is_a?(Spider::Model::Condition)
                        el_join_info = get_join_info(element.model, v) 
                        has_true = false
                        has_false = false
                        el_join_info.each do |jk, jv|
                            join_info["#{k}.#{jk}"] = jv
                            has_true = true if jv
                            has_false = true unless jv
                        end
                        if (v.conjunction == :and && has_true) || (has_true && !has_false)
                            join_info[k.to_s] = true
                        elsif (v.conjunction == :or && has_false) || (has_false && !has_true)
                            join_info[k.to_s] = false
                        end
                    end
                end
                sub = {}
                condition.subconditions.each do |sub_cond|
                    next if sub_cond.empty?
                    sub_join_info = get_join_info(model, sub_cond)
                    sub_join_info.each_key do |k|
                        if condition.conjunction == :or
                            sub[k] = true if sub_join_info[k] && sub[k] != false
                            sub[k] = false unless sub_join_info
                        else
                            sub[k] = true if sub_join_info[k]
                        end
                    end
                end
                join_info.merge!(sub)
                join_info
            end

            
            
            join_info = options[:join_info]
            join_info ||= get_join_info(@model, condition)


            condition.each_with_comparison do |k, v, comp|
                if k.is_a?(QueryFuncs::Function)
                    field = prepare_queryfunc(k)
                    cond[:values] << [field, comp, v]
                    joins += field.joins
                    next
                end
                element = model.elements[k.to_sym]
                next unless model.mapper.mapped?(element)
                if (element.model?)
                    el_join_info = {}
                    join_info.each do |jk, jv|
                        if jk.index(k.to_s+'.') == 0
                            el_join_info[jk[k.to_s.length+1..-1]] = jv
                        end
                    end
                    if (v && model.mapper.have_references?(element.name) && v.select{ |key, value| 
                        !element.model.elements[key] || !element.model.elements[key].primary_key? }.empty?)
                        # 1/n <-> 1 with only primary keys
                        element_cond = {:conj => 'AND', :values => []}
                        v.each_with_comparison do |el_k, el_v, el_comp|
                            field = model_schema.qualified_foreign_key_field(element.name, el_k)
                            el_comp ||= '='
                            op = el_comp
                            field_cond = [field, op,  map_condition_value(element.model.elements[el_k.to_sym].type, el_v)]
                            element_cond[:values] << field_cond
                        end
                        cond[:values] << element_cond
                    else
                        if element.storage == model.mapper.storage
                            join_type = join_info[element.name.to_s] ? :inner : :left
                            sub_join = model.mapper.get_join(element, join_type)
                            # FIXME! cleanup, and apply the check to joins acquired in other places, too (maybe pass the current joins to get_join)
                            existent = joins.select{ |j| j[:to] == sub_join[:to] }
                            j_cnt = nil
                            had_join = false
                            existent.each do |j|
                                if sub_join[:to] == j[:to] && sub_join[:keys] == j[:keys] && sub_join[:conditions] == j[:conditions]
                                    # if any condition allows a left join, then a left join should be used here as well
                                    j[:type] = :left if sub_join[:type] == :left
                                    sub_join = j
                                    had_join = true
                                    break
                                else
                                    j_cnt ||= 0; j_cnt += 1
                                end
                            end
                            sub_join[:as] = "#{sub_join[:to]}#{j_cnt}" if j_cnt
                            joins << sub_join unless had_join
                            
                            if v.nil? && comp == '='
                                el_model_schema = model_schema
                                element_cond = {:conj => 'AND', :values => []}
                                    if model.mapper.have_references?(element.name)
                                    el_name = element.name
                                    el_model = element.model
                                else
                                    el_model = element.type
                                    el_model_schema = element.model.mapper.schema 
                                    el_name = element.attributes[:junction_their_element]
                                end
                                el_model.primary_keys.each do |k|
                                    field = el_model_schema.qualified_foreign_key_field(el_name, k.name)
                                    field_cond = [field, comp,  map_condition_value(element.model.elements[k.name].type, nil)]
                                    element_cond[:values] << field_cond
                                end
                                cond[:values] << element_cond
                            elsif v
                                sub_condition, sub_joins = element.mapper.prepare_condition(v, :table => sub_join[:as], :joins => joins, :join_info => el_join_info)
                                sub_condition[:table] = sub_join[:as] if sub_join[:as]
                                joins = sub_joins
                                cond[:values] << sub_condition
                            end
                            
                        else
                           remaining_condition ||= Condition.new
                           remaining_condition.set(k, comp, v)
                        end
                    end
                elsif(model_schema.field(element.name))
                    field = model_schema.qualified_field(element.name, options[:table])
                    op = comp ? comp : '='
                    if (v.is_a?(Spider::QueryFuncs::Expression))
                        v_joins = prepare_expression(v)
                        joins += v_joins
                        cond[:values] << [field, op, v]
                    else
                        cond[:values] << [field, op, map_condition_value(model.elements[k.to_sym].type, v)]
                    end
                end
                
            end
            sub_sqls = []
            sub_bind_values = []
            condition.subconditions.each do |sub|
                sub_res = self.prepare_condition(sub, :joins => joins, :join_info => join_info)
                cond[:values] << sub_res[0]
                joins = sub_res[1]
                remaining_condition += sub_res[2]
            end
            return [cond, joins, remaining_condition]
        end


        # Figures out a join for element. Returns join hash description, i.e. :
        #   join = {
        #     :type => :inner|:outer|...,
        #     :from => 'table1',
        #     :to => 'table2',
        #     :keys => hash of key pairs,
        #     :condition => join condition
        #   }
        def get_join(element, join_type = :inner)
            return unless element.model?
            #Spider::Logger.debug("Getting join for model #{@model} to element #{element}")
            #Spider::Logger.debug(@model.primary_keys.map{|k| k.name})
            element_table = element.mapper.schema.table
            if (schema.has_foreign_fields?(element.name))
                #Spider::Logger.debug("JOIN A from #{@model} to #{element.name}")
                keys = {}
                element.model.primary_keys.each do |key|
                    if (key.integrated?)
                        # FIXME
                        raise "Unimplemented join dereference for multiple primary keys" if key.integrated_from.model.primary_keys.length > 1
                        el_field = element.mapper.schema.foreign_key_field(key.integrated_from.name, key.integrated_from.model.primary_keys[0].name)
                    else
                        el_field = element.mapper.schema.field(key.name)
                    end

                    fk = schema.foreign_key_field(element.name, key.name)
                    keys[fk] = el_field
                    # FIXME: works with models as primary keys through a hack in the field method of db_schema,
                    # assuming the model has only one key. the correct way would be to get another join
                end
                if (element.condition)
                    condition, condition_joins, condition_remaining = element.mapper.prepare_condition(element.condition)
                end
                as = nil
                if (element.model == @model)
                    as = "#{schema.table}_#{element.name}"
                end
                join = {
                    :type => join_type,
                    :from => schema.table,
                    :to => element.mapper.schema.table,
                    :keys => keys,
                    :condition => condition,
                    :as => as
                }
            elsif (element.has_single_reverse? && element.mapper.schema.has_foreign_fields?(element.reverse)) # n/1 <-> n
                #Spider::Logger.debug("JOIN B from #{@model} to #{element.name}")
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
                    :type => join_type,
                    :from => schema.table,
                    :to => element.mapper.schema.table,
                    :keys => keys,
                    :condition => condition
                }
            else # n <-> n
                # no need to handle n <-> n
            end
            # FIXME: add element conditions!
            return join
        end
        
        # Returns the joins needed for an element down the tree, expressed in dotted notation.
        # Returns a triplet composed of
        # * joins
        # * final model called
        # * final element called
        def get_deep_join(dotted_element)
            #return [[], @model, @model.elements[dotted_element]] unless dotted_element.is_a?(String)
            parts = dotted_element.to_s.split('.').map{ |el| el.to_sym }
            current_model = @model
            joins = []
            el = nil
#            Spider::Logger.debug("GETTING DEEP JOIN TO #{dotted_element} (#{@model})")
            parts.each do |part|
                el = current_model.elements[part]
                raise "Can't find element #{part} in model #{current_model}" unless el
                if (el.integrated?)
                    joins << current_model.mapper.get_join(el.integrated_from)
                    current_model = el.integrated_from.type
                    el = current_model.elements[el.integrated_from_element]
                end
                if (el.model? && can_join?(el))
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
        
        def prepare_queryfunc(func)
            joins = []
            func_elements = func.inner_elements
            func_elements.each do |el_name, owner_func|
                el_joins, el_model, el = get_deep_join(el_name)
                joins += el_joins
                owner_func.mapper_fields ||= {}
                owner_func.mapper_fields[el.name] = el_model.mapper.schema.field(el.name)
            end
            return FieldFunction.new(storage.function(func), schema.table, joins)
        end
        
        # Takes a Spider::QueryFuncs::Expression, and associates the fields to the corresponding elements
        # Returns an array of needed joins
        def prepare_expression(expr)
            joins = []
            expr.each_element do |v_el|
                v_joins, j_model, j_el = get_deep_join(v_el)
                db_field = j_model.mapper.schema.qualified_field(j_el.name)
                joins += v_joins
                expr[v_el] = db_field
            end
            return joins
        end
        
        # Returns a pair composed of
        # * fields, an array of [field, direction] couples; and
        # * joins, joins needed for the order, if any
        def prepare_order(query)
            joins = []
            fields = []
            query.order.each do |order|
                order_element, direction = order
                el_model = @model
                if (order_element.is_a?(QueryFuncs::Function))
                    field = prepare_queryfunc(order_element)
                    joins += field.joins
                    fields << [field, direction]
                else
                    el_joins, el_model, el = get_deep_join(order_element)
                    if (el.model?)
                        # FIXME: integrated elements
                        if el.model.storage != storage
                            el.model.primary_keys.each do |pk|
                                fields << [el_model.mapper.schema.foreign_key_field(el.name, pk.name), direction]
                            end
                        else
                            el.model.primary_keys.each do |pk|
                                fields << [el.model.mapper.schema.field(pk.name), direction]
                            end
                        end
                    else
                        raise "Order on unmapped element #{el_model.name}.#{el.name}" unless el_model.mapper.mapped?(el)
                        field = el_model.mapper.schema.field(el.name)
                        fields << [field, direction]
                    end
                    joins += el_joins
                end
            end
            return [fields, joins]
        end

        # Returns a type accepted by the storage for type.
        def map_type(type)
            st = type
            return Fixnum if st <= Spider::DataTypes::PK
            while (st && !storage.class.base_types.include?(st))
                st = Model.simplify_type(st)
            end
            return type unless st
            return st
        end
        
        # Converts a value in one accepted by the storage.
        def map_value(type, value, mode=nil)
            return value if value.nil?
            
            case type.name
            when 'Spider::DataTypes::Bool'
                value = value ? 1 : 0
            else
                value = super
            end
            
            return value
        end
        
        def map_back_value(type, value)
            case type.name
            when 'Spider::DataTypes::Bool'
                return value if value.nil?
                return value == 1 ? true : false
            end
            return super
        end
      
        
        ##############################################################
        #   Primary keys                                             #
        ##############################################################
        
        # Empty hook to set primary keys in the model before insert. Override if needed.
        def assign_primary_keys(obj)
            # may be implemented in model through the 'with_mapper' method
        end

        
        ##############################################################
        #   Storage strategy                                         #
        ##############################################################
        
        # UnitOfWork dependencies.
        def get_dependencies(task)
            deps = []
            obj = task.object
            action = task.action
            deps = []
            case action
            when :keys
                deps << [task, MapperTask.new(obj, :save)] unless obj.primary_keys_set? || (!obj.mapper || !obj.mapper.class.write?)
            when :save
                @model.primary_keys.each do |key|
                    if key.integrated? && !obj.element_has_value?(key)
                        obj.get(key.integrated_from) # ensure super object is instantiated, so it gets processed later
                    end
                end
                
                elements = @model.elements.select{ |n, el| !el.integrated? && el.model? && obj.element_has_value?(el) && obj.element_modified?(el)}
                
                elements.each do |name, element|
                    if have_references?(element)
                        el_obj = obj.send(element.name)
                        sub_task = MapperTask.new(el_obj, :keys)
                        deps << [task, sub_task]
                    else
                        if element.type.mapper && element.type.mapper.class.write?
                            el_val = obj.send(element.name)
                            if element.multiple?
                                set = el_val
                                if element.junction? && !element.attributes[:keep_junction]
                                    set = obj.send("#{element.name}_junction")
                                end
                                delete_ass = nil
                                if set.modified # queryset modified
                                    delete_ass = MapperTask.new(obj, :delete_associations, :element => element.name)
                                    deps << [task, delete_ass]
                                end
                                prev_task = nil
                                set.each do |set_obj|
                                    sub_task = MapperTask.new(set_obj, :save)
                                    if set_obj.class.attributes[:sub_model] && delete_ass
                                        set_obj.class.primary_keys.each{ |pk| set_obj.set(pk, nil) }
                                    end
                                    if prev_task
                                        deps << [sub_task, prev_task]
                                    else
                                        deps << [sub_task, task]
                                    end
                                    if delete_ass
                                        del_dep = set_obj
                                        if element.reverse
                                            set_obj.set_modified(element.reverse)
                                            el = set_obj.class.elements[element.reverse]
                                            # ensure the real owner is added as a dependency
                                            while el.integrated?
                                                del_dep = set_obj.get(el.integrated_from)
                                                el = del_dep.class.elements[el.integrated_from_element]
                                            end
                                        end
                                        deps << [MapperTask.new(del_dep, :save), delete_ass]
                                    end
                                    prev_task = sub_task
                                end
                            else
                                el_val.set_modified(element.reverse)
                                deps << [task, MapperTask.new(el_val, :save)]
                            end
                        end
                    end
                end
            end
            return deps
        end
        
        def execute_action(action, object, params={})
            return super unless action == :delete_associations
            el = object.class.elements[params[:element]]
            delete_element_associations(object, el)
        end
        
        
        ##############################################################
        #   Schema management                                        #
        ##############################################################

        # Extend schema. Given block will be instance_eval'd after schema auto generation.
        # See also #define_schema.
        def with_schema(&proc)
            @schema_procs ||= []
            @schema_procs << proc
        end
        
        # Define schema. Given block will be instance_eval'd before schema auto generation.
        # See also #with_schema.
        def define_schema(&proc)
            @schema_define_procs ||= []
            @schema_define_procs << proc
        end

        # Returns @schema, or creates one.
        def schema
            @schema ||= get_schema()
            return @schema
        end
        
        # Returns the schema, as defined or autogenerated.
        def get_schema
            schema = @model.superclass.mapper.get_schema() if (@model.attributes[:inherit_storage])
            if @schema_define_procs
                schema =  DbSchema.new
                @schema_define_procs.each do |schema_proc|
                    schema.instance_eval(&schema_proc)
                end
            end
            schema = generate_schema(schema)
            if @schema_procs
                @schema_procs.each do |schema_proc|
                    schema.instance_eval(&schema_proc)
                end
            end
            return schema
        end

        # Resets the schema, so that it is regenerated on the next call
        def reset_schema
            @schema = nil
        end

        def storage_column_type(type, attributes)
            @storage.column_type(type, attributes)
        end
        
        def storage_column_attributes(type, attributes)
            @storage.column_attributes(type, attributes)
        end
        
        def base_type(type)
            if type <= Spider::DataTypes::PK
                Fixnum
            else
                super
            end
        end

        # Autogenerates schema. Returns a DbSchema.
        def generate_schema(schema=nil)
            had_schema = schema ? true : false
            schema ||= DbSchema.new
            n = @model.name.sub('::Models', '')
            app = @model.app
            app_name = app.name if app
            short_prefix = app.short_prefix if app
            n.sub!(app_name, short_prefix) if short_prefix
            schema.table ||= @model.attributes[:db_table] || @storage.table_name(n)
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
                    column = schema.columns[element.name]
                    storage_type = base_type(element.type)
                    db_attributes = column.attributes if column
                    if (!db_attributes || db_attributes.empty?)
                        db_attributes = storage_column_attributes(storage_type, element.attributes)
                        db_attributes.merge(element.attributes[:db]) if (element.attributes[:db]) 
                        if (element.attributes[:autoincrement] && !db_attributes[:autoincrement])
                            schema.set_sequence(element.name, @storage.sequence_name("#{schema.table}_#{element.name}"))
                        end
                    end
                    column_type = element.attributes[:db_column_type] || storage_column_type(storage_type, element.attributes)
                    unless column
                        column_name = element.attributes[:db_column_name] || @storage.column_name(element.name)
                        column = Field.new(schema.table, column_name, column_type)
                    end
                    column.type ||= column_type
                    column.attributes = db_attributes                        
                    column.primary_key = true if element.primary_key?
                    schema.set_column(element.name, column)
                elsif (true) # FIXME: must have condition element.storage == @storage in some of the subcases
                    if (!element.multiple? && !element.attributes[:junction] && !element.attributes[:condition]) # 1/n <-> 1
                        current_schema = schema.foreign_keys[element.name] || {}
                        foreign_key_constraints = {}
                        el_mapper = element.type.mapper
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
                            column = current_schema[key.name]
                            key_storage_type = el_mapper.base_type(key_type)
                            column_type = element.attributes[:db_column_type] || storage_column_type(key_storage_type, key_attributes)
                            unless column
                                column_name = element.attributes[:db_column_name] || @storage.column_name("#{element.name}_#{key.name}")
                                column_attributes = @storage.column_attributes(key_type, key_attributes)
                                column = Field.new(schema.table, column_name, column_type, column_attributes)
                            end
                            column.type ||= column_type
                            column.primary_key = true if (element.primary_key? || integrated_pks.include?([element.name, key.name]))
                            schema.set_foreign_key(element.name, key.name, column)
                        end

                    end
                end
            end
            @model.sequences.each do |name|
                schema.set_sequence(name, @storage.sequence_name("#{schema.table}_#{name}"))
            end
            return schema
        end
        
        def compute_foreign_key_constraints
            @model.each_element do |element|
                foreign_key_constraints = {}
                next if element.integrated?
                next unless mapped?(element)
                next if element.attributes[:added_reverse] && element.has_single_reverse?
                next unless element.model?
                next if element.multiple?
                next unless element.type.mapper.storage == @storage
                element.type.primary_keys.each do |key|
                    column =  self.schema.foreign_key_field(element.name, key.name)
                    column_name = column.name
                    next if !key.integrated? && !element.type.mapper.schema.column(key.name) # FIXME
                    foreign_key_constraints[column_name] = key.integrated? ? \
                    element.type.mapper.schema.foreign_key_field(key.integrated_from.name, key.integrated_from_element).name : \
                    element.type.mapper.schema.column(key.name).name
                end
                unless foreign_key_constraints.empty?
                    name = element.attributes[:db_foreign_key_name] || "FK_#{schema.table.name}_#{element.name}"
                    self.schema.set_foreign_key_constraint(name, element.type.mapper.schema.table.name, foreign_key_constraints)
                end
            end
        end

        # Returns an array of all keys, "dereferencing" model keys.
        def collect_real_keys(element, path=[]) # :nodoc:
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

        # Modifies the storage according to the schema.
        def sync_schema(force=false, options={})
            compute_foreign_key_constraints unless options[:no_foreign_key_constraints] || !storage.supports?(:foreign_keys)
            schema_description = schema.get_schemas
            sequences = {}
            sequences[schema.table] = schema.sequences

            @model.elements_array.select{ |el| el.attributes[:anonymous_model] }.each do |el|
                next if el.model.mapper.class != self.class
                el.model.mapper.compute_foreign_key_constraints
                schema_description.merge!(el.model.mapper.schema.get_schemas)
                sequences[el.model.mapper.schema.table] ||= {}
                sequences[el.model.mapper.schema.table].merge!(el.model.mapper.schema.sequences)
                # Spider::Logger.debug("MERGING SEQUENCES:")
                # Spider::Logger.debug(el.model.mapper.schema.sequences)
                # sequences.merge!(el.model.mapper.schema.sequences)
            end
            schema_description.each do |table_name, table_schema|
                table_attributes = {
                    :primary_keys => table_schema[:attributes][:primary_keys]
                }
                unless options[:no_foreign_key_constraints] || !storage.supports?(:foreign_keys)
                    table_attributes[:foreign_key_constraints] = table_schema[:attributes][:foreign_key_constraints] || []
                end
                if @storage.table_exists?(table_name)
                    alter_table(table_name, table_schema, table_attributes, force)
                else
                    create_table(table_name, table_schema, table_attributes)
                end
                if (options[:drop_fields])
                    current = @storage.describe_table(table_name)[:columns]
                    current.each_key do |cur|
                        @storage.drop_field(table_name, cur) if (!table_schema[:columns][cur])
                    end
                end
            end
            seen = {}
            sequences.each do |sequence_table, table_sequences|
                table_sequences.each do |element_name, db_name|
                    next if seen[db_name]
                    if storage.sequence_exists?(db_name)
                        if (options[:update_sequences])
                            sql = "SELECT MAX(#{schema.field(element_name).name}) AS M FROM #{sequence_table}"
                            res = @storage.execute(sql)
                            max = res[0]['M'].to_i
                            storage.update_sequence(db_name, max+1)
                        end
                    else
                        storage.create_sequence(db_name)
                    end
                    seen[db_name] = true
                end
            end
        end

        # Returns a create table structure description.
        def create_table(table_name, schema, attributes) # :nodoc:
            fields = schema[:fields_order].uniq.map do |f| 
                details = schema[:columns][f.name]
                {
                    :name => f.name,
                    :type => details[:type],
                    :attributes => details[:attributes]  
                }
            end
            @storage.create_table({
                :table => table_name,
                :fields => fields,
                :attributes => attributes
            })
        end

        # Returns an alter table structure description
        def alter_table(name, schema, attributes, force=nil) # :nodoc:
            current = @storage.describe_table(name)
            current_fields = current[:columns]
            add_fields = []
            alter_fields = []
            all_fields = []
            unsafe = []
            fields = schema[:columns]
            schema[:fields_order].each do |f|
                field = f.name
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
                    field_attributes = fields[field][:attributes]
                    field_attributes ||= {}
                    if (!@storage.schema_field_equal?(current_fields[field], fields[field]))
                        # Spider.logger.debug("DIFFERENT: #{field}")
                        # Spider.logger.debug(current_fields[field])
                        # Spider.logger.debug(fields[field])
                        unless @storage.safe_schema_conversion?(current_fields[field], fields[field]) || force
                            unsafe << field 
                            next
                        end
                        alter_fields << field_hash
                    end
                end
                
            end
            alter_attributes = {}
            if (current[:primary_keys] != attributes[:primary_keys])
                alter_attributes[:primary_keys] = attributes[:primary_keys]
            end
            if (attributes[:foreign_key_constraints])
                
            end
            alter_attributes[:foreign_key_constraints] = attributes[:foreign_key_constraints]
            @storage.alter_table({
                :table => name,
                :add_fields => add_fields,
                :alter_fields => alter_fields,
                :all_fields => all_fields,
                :attributes => alter_attributes,
                :current => current
            })
            raise SchemaSyncUnsafeConversion.new(unsafe) unless unsafe.empty?
        end
        
        ##############################################################
        #   Aggregates                                               #
        ##############################################################

        def max(element, condition=nil)
            element = @model.elements[element] if element.is_a?(Symbol)
            schema = element.integrated? ? @model.elements[element.integrated_from.name].model.mapper.schema : self.schema
            max = {}
            max[:condition], joins = prepare_condition(condition) if condition
            max[:tables] = [schema.table]
            max[:field] = schema.field(element.name)
            joins ||= []
            max[:joins] = prepare_joins(joins)
            sql, values = storage.sql_max(max)
            res = storage.execute(sql, *values)
            return res[0] && res[0]['M'] ? res[0]['M'] : 0
        end
        

    end

    # Error raised when a conversion results in a potential data loss.
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
