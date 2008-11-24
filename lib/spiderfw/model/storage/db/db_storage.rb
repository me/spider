require 'spiderfw/model/storage/base_storage'

module Spider; module Model; module Storage; module Db
    
    class DbStorage < Spider::Model::Storage::BaseStorage
        @reserved_keywords = ['from', 'order', 'where']
        def self.reserved_keywords
            @reserved_keywords
        end
        
        def initialize(url)
            super
        end
        
        def get_mapper(model)
            require 'spiderfw/model/mappers/db_mapper'
            mapper = Spider::Model::Mappers::DbMapper.new(model, self)
            return mapper
        end
        
        def supports_transactions?
            return false
        end
        
        def start_transaction
           raise StorageException, "The current storage does not support transactions" 
        end
        
        def in_transaction?
            return false
        end
        
        def commit
        end
        
        def rollback
            raise StorageException, "The current storage does not support transactions" 
        end
        
        def lock(table, mode=:exclusive)
            lockmode = case(mode)
            when :shared
                'SHARE'
            when :row_exclusive
                'ROW EXCLUSIVE'
            else
                'EXCLUSIVE'
            end
            execute("LOCK TABLE #{table} IN #{lockmode} MODE")
        end
        
        def assigned_key(name)
        end
        
        ##############################################################
        #   Methods used to generate a schema                        #
        ##############################################################
        
        # Fixes a string to be used as a table name
        def table_name(name)
            return name.to_s.gsub(':', '_')
        end
        
        # Fixes a string to be used as a column name
        def column_name(name)
            name = name.to_s
            name += '_field' if (self.class.reserved_keywords.include?(name.downcase)) 
            return name
        end
        
        # Returns the db type corresponding to an element type
        def column_type(type)
            case type
            when 'text'
                'TEXT'
            when 'longText'
                'LONGTEXT'
            when 'int'
                'INT'
            when 'real'
                'REAL'
            when 'dateTime'
                'DATE'
            when 'binary'
                'BLOB'
            when 'bool'
                'INT'
            end
        end
        
        # Returns the attributes corresponding to element type and attributes
        def column_attributes(type, attributes)
            db_attributes = {}
            case type
            when 'text', 'longText'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
            when 'real'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
                db_attributes[:precision] = attributes[:precision] if (attributes[:precision])
            when 'binary'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
            when 'bool'
                db_attributes[:length] = 1
            end
            return db_attributes
        end
        
        ##################################################################
        #   Preparing values                                             #
        ##################################################################
        
        def value_for_save(type, value, save_mode)
            return value
        end
        
        def value_for_condition(type, value)
            return value
        end
        
        def value_to_mapper(type, value)
            return value
        end
        
        def query(query)
            case query[:query_type]
            when :select
                sql, bind_vars = sql_select(query)
                execute(sql, *bind_vars)
            when :count
                query[:keys] = 'COUNT(*) AS N'
                sql, bind_vars = sql_select(query)
                return execute(sql, *bind_vars)[0]['N']
            end
        end
        
        def sql_select(query)
            bind_vars = query[:bind_vars] || []
            sql = "SELECT #{sql_keys(query)} FROM #{sql_tables(query)} "
            where, vals = sql_condition(query)
            bind_vars += vals
            sql += "WHERE #{where} " if where && !where.empty?
            order = sql_order(query)
            sql += "ORDER BY #{order} " if order && !order.empty?
            limit = sql_limit(query)
            sql += limit if limit
            return sql, bind_vars
        end
        
        def sql_keys(query)
            query[:keys].join(',')
        end
        
        def sql_tables(query)
            query[:tables].join(',')
        end
        
        
        def sql_condition(query)
            condition = query[:condition]
            return ['', []] unless (condition && condition[:values])
            bind_vars = []
            mapped = condition[:values].map do |v|
                if (v.is_a? Hash) # subconditions
                    sql, vals = sql_condition({:condition => v})
                    bind_vars += vals
                    !sql.empty? ? "(#{sql})" : nil
                else
                    bind_vars << v[2]
                    sql_condition_value(v[0], v[1], v[2])
                end
            end
            return mapped.select{ |p| p != nil}.join(' '+condition[:conj]+' '), bind_vars
        end
        
        def sql_condition_value(key, comp, value)
            "#{key} #{comp} ?"
        end
        
        def sql_join(joins)
            sql = ""
            joins.each_key do |from_table|
                joins[from_table].each do |to_table, conditions|
                    conditions.each do |from_key, to_key|
                        sql += " AND " unless sql.empty?
                        sql += "#{from_table}.#{from_key} = #{to_table}.#{to_key}"
                    end
                end
            end
            return sql
        end
        
        def sql_order(query)
            return '' unless query[:order]
            query[:order].map{|o| "#{o[0]} #{o[1]}"}.join(' ,')
        end
        
        def sql_limit(query)
            sql = ""
            sql += "LIMIT #{query[:limit]} " if query[:limit]
            sql += "OFFSET #{query[:offset]} " if query[:offset]
        end
        
        def sql_insert(insert)
            sql = "INSERT INTO #{insert[:table]} (#{sql_insert_keys(insert)}) VALUES (#{sql_insert_values(insert)})"
            return [sql, insert[:values].values]
        end
        
        def sql_insert_keys(insert)
            insert[:values].keys.join(', ')
        end
        
        def sql_insert_values(insert)
            insert[:values].values.map{'?'}.join(', ')
        end
            
        def sql_update(update)
            values = update[:values].values
            sql = "UPDATE #{update[:table]} SET "
            sql += sql_update_values(update)
            where, bind_vars = sql_condition(update)
            values += bind_vars
            sql += " WHERE #{where}"
            return [sql, values]
        end
        
        def sql_update_values(update)
            update[:values].map{ |k, v| 
                "#{k} = ?"
            }.join(', ')
        end
        
        def sql_delete(delete)
            where, bind_vars = sql_condition(delete)
            sql = "DELETE FROM #{delete[:table]} WHERE #{where}"
            return [sql, bind_vars]
        end
            
            
        
    end
    
end; end; end; end