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
        
        def save_all(root) #:nodoc:
            @storage.start_transaction
            super
            @storage.commit
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
                                next if store_key.is_a?(FieldExpression)
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
                condition[key.name] = map_condition_value(key.type, obj.get(key))
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
            return set
        end
        
        # Implements the Mapper#map method.
        # Converts a DB result row to an object.
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
                    data[element_name] = keys_set ? Spider::Model.get(element.model, pks) : nil
#                    rescue IdentityMapperException
                        # null keys, nothing to set
#                    end
                elsif !element.model?
                    data[element_name] = map_back_value(element.type, result[schema.field(element_name).name])
                end
            end
            begin
                obj = Spider::Model.get(model, data)
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
            if (query.limit && query.order.empty?)
                @model.primary_keys.each do |key|
                    elements << key.name unless elements.include?(key.name)
                    query.order_by(key.name, :asc)
                end
            end
            order, order_joins = prepare_order(query)
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
                    unless seen_fields[field.name]
                        keys << field
                        primary_keys << field if model_pks.include?(el)
                        seen_fields[field.name] = true
                    end
                elsif !element.attributes[:junction]
                    if schema.has_foreign_fields?(el)
                        element.model.primary_keys.each do |key|
                            field = schema.foreign_key_field(el, key.name)
                            raise "Can't find a foreign key field for key #{key.name} of element #{el} of model #{@model}" unless field
                            unless seen_fields[field.name]
                                keys << field
                                primary_keys << field if model_pks.include?(el)
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
                :primary_keys => primary_keys,
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
            # FIXME: move to mapper
            model = condition.polymorph ? condition.polymorph : @model
            model_schema = model.mapper.schema
            cond = {}
            # debugger if condition.polymorph
            condition.each_with_comparison do |k, v, comp|
                next if k.is_a?(QueryFuncs::Function)
                # normalize condition values
                element = model.elements[k.to_sym]
                if (v && !v.is_a?(Condition) && element.model?)
                    condition.delete(element.name)
                    def set_pks_condition(condition, el, val, prefix)
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
            bind_values = []
            joins = options[:joins] || []
            remaining_condition = Condition.new # TODO: implement
            cond[:conj] = condition.conjunction.to_s
            cond[:values] = []
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
                    if (v && model.mapper.have_references?(element.name) && v.select{ |key, value| !element.model.elements[key].primary_key? }.empty?)
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
                        if (element.storage == model.mapper.storage)
                            if v.nil?
                                join_type = comp == '=' ? :left : :inner
                            else
                                join_type = :inner
                            end
                            sub_join = model.mapper.get_join(element, join_type)
                            # FIXME! cleanup, and apply the check to joins acquired in other places, too (maybe pass the current joins to get_join)
                            existent = joins.select{ |j| j[:to] == sub_join[:to] }
                            j_cnt = nil
                            had_join = false
                            existent.each do |j|
                                if sub_join[:to] == j[:to] && sub_join[:keys] == j[:keys] && sub_join[:conditions] == j[:conditions]
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
                                element_cond = {:conj => 'AND', :values => []}
                                element.model.primary_keys.each do |k|
                                    field = model_schema.qualified_foreign_key_field(element.name, k.name)
                                    field_cond = [field, comp,  map_condition_value(element.model.elements[k.name].type, nil)]
                                    element_cond[:values] << field_cond
                                end
                                cond[:values] << element_cond
                            elsif v
                                v = element.model.mapper.preprocess_condition(v)                          
                                sub_condition, sub_joins = element.mapper.prepare_condition(v, :table => sub_join[:as], :joins => joins)
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
                sub_res = self.prepare_condition(sub, :joins => joins)
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
            Spider::Logger.debug("Getting join for model #{@model} to element #{element}")
            Spider::Logger.debug(@model.primary_keys.map{|k| k.name})
            element_table = element.mapper.schema.table
            if (schema.has_foreign_fields?(element.name))
                Spider::Logger.debug("JOIN A from #{@model} to #{element.name}")
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
                    fk = fk.expression if fk.is_a?(FieldExpression)
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
                Spider::Logger.debug("JOIN B from #{@model} to #{element.name}")
                keys = {}
                @model.primary_keys.each do |key|
                    our_field = nil
                    if (key.integrated?)
                        our_field = schema.foreign_key_field(key.integrated_from.name, key.integrated_from_element)
                    else
                        our_field = schema.field(key.name)
                    end
                    keys[our_field] = element.mapper.schema.foreign_key_field(element.reverse, key.name)
                    keys[our_field] = keys[our_field].expression if keys[our_field].is_a?(FieldExpression)
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
            Spider::Logger.debug("GETTING DEEP JOIN TO #{dotted_element} (#{@model})")
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
                        if !joins.empty?
                            el.model.primary_keys.each do |pk|
                                fields << [el.model.mapper.schema.field(pk.name), direction]
                            end
                        else
                            el.model.primary_keys.each do |pk|
                                fields << [schema.qualified_foreign_key_field(el.name, pk.name), direction]
                            end
                        end
                    else
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
            while (st && !storage.class.base_types.include?(st))
                st = Model.simplify_type(st)
            end
            return type unless st
            return st
        end
        
        # Converts a value in one accepted by the storage.
        def map_value(type, value, mode=nil)
            return value if value.nil?
             if (type < Spider::DataType && value)
                 value = type.from_value(value) unless value.is_a?(type)
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
         def map_save_value(type, value, save_mode)
             value = map_value(type, value, :save)
             return @storage.value_for_save(Model.simplify_type(type), value, save_mode)
         end

        # Prepares a value for a condition.
        def map_condition_value(type, value)
            if value.is_a?(Range)
                return Range.new(map_condition_value(type, value.first), map_condition_value(type, value.last))
            end
            return value if ( type.class == Class && type.subclass_of?(Spider::Model::BaseModel) )
            value = map_value(type, value, :condition)
            return @storage.value_for_condition(Model.simplify_type(type), value)
        end

        def storage_value_to_mapper(type, value)
            storage.value_to_mapper(type, value)
        end

        # Converts a storage value back to the corresponding base type or DataType.
        def map_back_value(type, value)
            value = value[0] if value.class == Array
            value = storage_value_to_mapper(Model.simplify_type(type), value)
            if (type < Spider::DataType && type.maps_back_to)
                type = type.maps_back_to
            end
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
            when 'Date', 'DateTime'
                return type.parse(value) unless value.is_a?(Date)
            end
            if (type < Spider::DataType)
                value = type.from_value(value)
            end
            return value
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

        # Extend schema. Given block will be instance_eval'd after schema auto generation.
        # See also #define_schema.
        def with_schema(*params, &proc)
            @schema_proc = proc
        end
        
        # Define schema. Given block will be instance_eval'd before schema auto generation.
        # See also #with_schema.
        def define_schema(*params, &proc)
            @schema_define_proc = proc
        end

        # Returns @schema, or creates one.
        def schema
            @schema ||= get_schema()
            return @schema
        end
        
        # Returns the schema, as defined or autogenerated.
        def get_schema
            schema = @model.superclass.mapper.get_schema() if (@model.attributes[:inherit_storage])
            if (@schema_define_proc)
                schema =  DbSchema.new
                schema.instance_eval(&@schema_define_proc)
            end
            schema = generate_schema(schema)
            if (@schema_proc)
                schema.instance_eval(&@schema_proc)
            end
            return schema
        end

        def storage_column_type(type, attributes)
            @storage.column_type(type, attributes)
        end

        # Autogenerates schema. Returns a DbSchema.
        def generate_schema(schema=nil)
            had_schema = schema ? true : false
            schema ||= DbSchema.new
            n = @model.name.sub('::Models', '')
            n.sub!(@model.app.name, @model.app.short_prefix) if @model.app.short_prefix
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
                    storage_type = Spider::Model.base_type(element.type)
                    db_attributes = column.attributes if column
                    if (!db_attributes || db_attributes.empty?)
                        db_attributes = @storage.column_attributes(storage_type, element.attributes)
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
                    if (!element.multiple? && !element.attributes[:junction]) # 1/n <-> 1
                        current_schema = schema.foreign_keys[element.name] || {}
                        foreign_key_constraints = {}
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
                            column_type = element.attributes[:db_column_type] || @storage.column_type(key_type, key_attributes)
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
            compute_foreign_key_constraints
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
            fields = schema[:fields_order].map do |f| 
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
