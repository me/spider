require 'spiderfw/model/storage/db/db_storage'
require 'spiderfw/model/storage/db/dialects/no_total_rows'

module Spider; module Model; module Storage; module Db
    
    
    class MSSQL < DbStorage
        include Dialects::NoTotalRows
        
        def self.capabilities
            {
                :autoincrement => true,
                :sequences => false,
                :transactions => true,
                :foreign_keys => false # not implemented
            }
        end
        
        def column_type(type, attributes)
            case type.name
            when 'String'
                'nvarchar'
            when 'Text'
                'ntext'
            when 'Fixnum'
                'int'
            when 'Float'
                'real'
            when 'BigDecimal', 'Spider::DataTypes::Decimal'
                'decimal'
            when 'Date', 'DateTime'
                'datetime'
            when 'Spider::DataTypes::Binary'
                'varbinary'
            when 'Spider::DataTypes::Bool'
                'bit'
            end
        end
        
        def query(query)
            return super unless query[:query_type] == :count
            @last_query = query
            query[:keys] = ['COUNT(*) AS N']
            query[:order] = []
            sql, bind_vars = sql_select(query)
            return execute("#{sql} AS CountResult", *bind_vars)[0]['N'].to_i
        end
        
        def sql_select(query)
            bind_vars = query[:bind_vars] || []
            if query[:limit] # Oracle is so braindead
                replaced_fields = {}
                replace_cnt = 0
                # add first field to order if none is found; order is needed for limit
                query[:order] << [query[:keys][0], 'desc'] if query[:order].length < 1
                query[:order].each do |o|
                    field, direction = o
                    transformed = "O#{replace_cnt += 1}"
                    replaced_fields[field] = transformed
                    query[:keys] << "#{field} AS #{transformed}"
                end
            end
            keys = sql_keys(query)
            order = sql_order(query)
            if (query[:limit])
                keys += ", row_number() over (order by #{order}) mssql_row_num"
            end
            tables_sql, tables_values = sql_tables(query)
            sql = "SELECT #{keys} FROM #{tables_sql} "
            bind_vars += tables_values
            where, vals = sql_condition(query)
            bind_vars += vals
            sql += "WHERE #{where} " if where && !where.empty?
            order = sql_order(query)
            if (query[:limit])
                if (query[:offset])
                    limit = "mssql_row_num between ? and ?"
                    bind_vars << query[:offset] + 1
                    bind_vars << query[:offset] + query[:limit]
                else
                    limit = "mssql_row_num < ?"
                    bind_vars << query[:limit] + 1
                end
                replaced_fields.each do |f, repl|
                    order = order.gsub(f, repl)
                end
                sql = "SELECT * FROM (#{sql}) as RowConstrainedResult WHERE #{limit} order by #{order}"
            else
                sql += "ORDER BY #{order} " if order && !order.empty?
            end
            return sql, bind_vars
        end
        
        def parse_db_column(col)
            type, attributes = col[:type].split(' ', 2)
            attributes = attributes.split(' ') if attributes
            col[:type] = type
            return col
        end
        
        def reflect_column(table, column_name, column_attributes)
            column_type = column_attributes[:type]
            el_type = nil
            el_attributes = {}
            case column_type
            when 'varchar', 'nvarchar', 'char', 'nchar'
                el_type = String
            when 'text', 'ntext'
                el_type = Spider::DataTypes::Text
            when 'int', 'smallint'
                el_type = Fixnum
            when 'bit'
                el_type = Spider::DataTypes::Bool
            when 'real'
                el_type = Float
            when 'decimal'
                el_type = BigDecimal
            when 'datetime'
                el_type = DateTime
            when 'varbinary'
                el_type = Spider::DataTypes::Binary
            end
            return el_type, el_attributes

        end
        
    end
    
    
end; end; end; end