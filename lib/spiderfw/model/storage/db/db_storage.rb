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
        
        def query(query)
            case query[:type]
            when :select
                execute(sql_select(query), *query[:bind_vars])
            when :count
                query[:keys] = 'COUNT(*) AS N'
                return execute(sql_select(query), *query[:bind_vars])[0]['N']
            end
        end
        
        def sql_select(query)
            sql = "SELECT #{sql_keys(query)} FROM #{sql_tables(query)} "
            where = sql_where(query)
            sql += "WHERE #{where} " if where && !where.empty?
            order = sql_order(query)
            sql += "ORDER BY #{order} " if order && !order.empty?
            limit = sql_limit(query)
            sql += limit if limit
            return sql
        end
        
        def sql_keys(query)
            query[:keys].join(',')
        end
        
        def sql_tables(query)
            query[:tables].join(',')
        end
        
        def sql_where(query)
            query[:condition]
        end
        
        def sql_order(query)
            query[:order] if query[:order] && query[:order].length > 0
        end
        
        def sql_limit(query)
            sql = ""
            sql += "LIMIT #{query[:limit]} " if query[:limit]
            sql += "OFFSET #{query[:offset]} " if query[:offset]
        end
            
            
        
    end
    
end; end; end; end