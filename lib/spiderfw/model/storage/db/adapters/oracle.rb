require 'spiderfw/model/storage/db/db_storage'

module Spider; module Model; module Storage; module Db
    
    class Oracle < DbStorage
        @capabilities = {
            :autoincrement => false,
            :sequences => true,
            :transactions => true,
            :foreign_keys => true
        }
        @reserved_keywords = superclass.reserved_keywords + ['oci8_row_num', 'file', 'uid', 'name', 'comment']
        @safe_conversions = {
            'CHAR' => ['VARCHAR', 'CLOB'],
            'VARCHAR' => ['CLOB'],
            'NUMBER' => ['VARCHAR']
        }
        class << self; attr_reader :reserved_kewords, :safe_conversions end
        
        def self.base_types
            super << Spider::DataTypes::Binary
        end
        

        
        def parse_url(url)
            # db:oracle://<username:password>:connect_role@<database>
            # where database is
            # the net8 connect string or
            # for Oracle client 10g or later, //hostname_or_ip:port_no/oracle_sid
            if (url =~ /.+:\/\/(?:(.+):(.+)(?::(.+))?@)?(.+)/)
                @user = $1
                @pass = $2
                @role = $3
                @dbname = $4
            else
                raise ArgumentError, "Oracle url '#{url}' is invalid"
            end
            @connection_params = [@user, @pass, @dbname, @role]
        end
        

        
        def value_for_condition(type, value)
            return value if value.nil?
            super
        end
        
        def value_to_mapper(type, value)
            case type.name
            when 'Date', 'DateTime'
                return nil unless value
                return value if value.class == type
                return value.to_datetime if type == DateTime
                return value.to_date # FIXME: check what is returned, here we espect an OCI8::Date
            when 'Spider::DataTypes::Text'
                value = value.read if value.respond_to?(:read)
            when 'Spider::DataTypes::Decimal', 'BigDecimal'
                value = value.to_s
            end
            return super(type, value)
        end


         
         def total_rows
             return nil unless curr[:last_executed]
             q = curr[:last_query].clone
             unless (q[:offset] || q[:limit])
                 return curr[:last_result] ? curr[:last_result].length : nil
             end
             q.delete(:offset); q.delete(:limit)
             q[:query_type] = :count
             sql, vars = sql_select(q)
             res = execute("SELECT COUNT(*) AS N FROM (#{sql})", *vars)
             return nil unless res && res[0]
             return res[0]['N'].to_i
         end
         
         def sequence_next(sequence_name)
             res = execute("SELECT #{sequence_name}.NEXTVAL AS NEXT FROM DUAL")
             return res[0]['NEXT'].to_i
         end

         
         ##############################################################
         #   SQL methods                                              #
         ##############################################################
         
         def sql_drop_primary_key(table_name)
             constraint_name = nil
             connection do |conn|
                 res = conn.exec("SELECT cons.CONSTRAINT_NAME FROM USER_CONSTRAINTS cons, user_cons_columns cols 
                                    WHERE cons.constraint_type = 'P'
                                    AND cons.constraint_name = cols.constraint_name
                                    AND cols.table_name = '#{table_name}'")
                 if h = res.fetch_hash
                     constraint_name = h['CONSTRAINT_NAME']
                 end
             end
             "ALTER TABLE #{table_name} DROP CONSTRAINT #{constraint_name}"
         end
         
         def sql_drop_foreign_key(table_name, key_name)
             "ALTER TABLE #{table_name} DROP CONSTRAINT #{key_name}"
         end
         
         
         def sql_select(query)
             curr[:bind_cnt] = 0
             # Spider::Logger.debug("SQL SELECT:")
             # Spider::Logger.debug(query)
             bind_vars = query[:bind_vars] || []
             query[:order_replacements] ||= {}
             if query[:limit] # Oracle is so braindead
                 replace_cnt = 0
                 # add first field to order if none is found; order is needed for limit
                 query[:order] << [query[:keys][0], 'desc'] if query[:order].length < 1
                 query[:order].each do |o|
                     field, direction = o
                     # i = query[:keys].index(field)
                     #   unless i
                     #       query[:keys].push(field)
                     #       i = query[:keys].length < 1
                     #   end
                     transformed = "O#{replace_cnt += 1}"
                     query[:order_replacements][field.to_s] = transformed
                     if field.is_a?(Spider::Model::Storage::Db::Field) && !query[:tables].include?(field.table)
                         query[:order_on_different_table] = true 
                     end
                     if field.is_a?(FieldFunction)
                         query[:order_on_different_table] = true if field.joins.length > 0
                     end
                     if (field.is_a?(Spider::Model::Storage::Db::Field) && field.type == 'CLOB')
                         field = "CAST(#{field} as varchar2(100))"
                     end
                     
                     query[:keys] << Db::FieldExpression.new(field.table, transformed, field.type, :expression => "#{field}")
                 end
             end
             keys = sql_keys(query)
             tables_sql, tables_values = sql_tables(query)
             sql = "SELECT #{keys} FROM #{tables_sql} "
             bind_vars += tables_values
             where, vals = sql_condition(query)
             bind_vars += vals
             sql += "WHERE #{where} " if where && !where.empty?
             order = sql_order(query, query[:order_replacements])
             if (query[:limit] || query[:query_type] == :count)
                 limit = nil
                 if (query[:offset])
                     limit = "oci8_row_num between :#{curr[:bind_cnt]+=1} and :#{curr[:bind_cnt]+=1}"
                     bind_vars << query[:offset] + 1
                     bind_vars << query[:offset] + query[:limit]
                 elsif query[:limit]
                     limit = "oci8_row_num < :#{curr[:bind_cnt]+=1}"
                     bind_vars << query[:limit] + 1
                 end
                 if (!query[:joins].empty?)
                     data_tables_sql = query[:order_on_different_table] ? tables_sql : query[:tables].join(', ')
                     pk_sql = query[:primary_keys].reject{ |pk| pk.is_a?(Db::FieldExpression) }.join(', ')
                     distinct_sql = "SELECT DISTINCT #{pk_sql} FROM #{tables_sql}"
                     distinct_sql += " WHERE #{where}" if where && !where.empty?
                     data_sql = "SELECT #{keys} FROM #{data_tables_sql} WHERE (#{pk_sql}) IN (#{distinct_sql})"
                     data_sql += " order by #{order}" unless order.blank?
                 else
                     data_sql = sql
                     data_sql += " order by #{order}" unless order.blank?
                 end
                 count_sql = "SELECT /*+ FIRST_ROWS(n) */ a.*, ROWNUM oci8_row_num FROM (#{data_sql}) a"
                 if limit
                     sql = "SELECT * FROM (#{count_sql}) WHERE #{limit}"
                 else
                     sql = count_sql
                 end
             else
                 sql += "ORDER BY #{order} " if order && !order.empty?
             end
             return sql, bind_vars
         end
         
         def sql_limit(query)
             # already done in sql_condition
         end
         
         def sql_condition_value(key, comp, value, bound_vars=true)
             curr[:bind_cnt] ||= 0
             if (comp.to_s.downcase == 'ilike')
                 comp = 'like'
                 key = "UPPER(#{key})"
             end
             if (value.nil?)
                 comp = comp == '=' ? "IS" : "IS NOT"
                 sql = "#{key} #{comp} NULL"
             else
                 if comp.to_s.downcase == 'between'
                     if bound_vars
                         val0 = ":#{(curr[:bind_cnt] += 1)}"; val1 = ":#{(curr[:bind_cnt] += 1)}"
                     else
                         val0, val1 = value
                     end
                     sql = "#{key} #{comp} #{val0} AND #{val1}"
                 else
                     val = bound_vars ? ":#{(curr[:bind_cnt] += 1)}" : value
                     sql = "#{key} #{comp} #{val}"
                     if comp == '<>'
                         sql = "(#{sql} or #{key} IS NULL)"
                     end
                 end
             end
             return sql
         end
         
         def sql_insert(insert)
             curr[:bind_cnt] = 0
             keys = insert[:values].keys.join(', ')
             vals = insert[:values].values.map{":#{(curr[:bind_cnt] += 1)}"}
             vals = vals.join(', ')
             sql = "INSERT INTO #{insert[:table]} (#{keys}) " +
                   "VALUES (#{vals})"
             return [sql, insert[:values].values]
         end
         
         def sql_insert_values(insert)
             insert[:values].values.map{":#{(curr[:bind_cnt] += 1)}"}.join(', ')
         end
         
         def sql_update(query)
             curr[:bind_cnt] = 0
             super
         end
         
         def sql_update_values(update)
             update[:values].map{ |k, v| 
                 val = v.is_a?(Spider::QueryFuncs::Expression) ? v : ":#{(curr[:bind_cnt] += 1)}"
                 "#{k} = #{val}"
             }.join(', ')
         end
         
         def sql_delete(del, force=false)
             curr[:bind_cnt] = 0
             super
         end
         
         def sql_alter_field(table_name, name, type, attributes)
             ["ALTER TABLE #{table_name} MODIFY #{sql_table_field(name, type, attributes)}"]
         end
         
         def sequence_exists?(sequence_name)
             check = "select SEQUENCE_NAME from user_sequences where sequence_name = :1"
             res = execute(check, sequence_name)
             return res[0] ? true : false
         end
         
         def create_sequence(sequence_name, start=1, increment=1)
             execute("create sequence #{sequence_name} start with #{start} increment by #{increment}")
         end

         def update_sequence(name, val)
             execute("drop sequence #{name}")
             create_sequence(name, val)
         end

         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################
         
         def post_execute
             curr[:bind_cnt] = 0
         end

         def list_tables
             tables = execute("SELECT TABLE_NAME FROM user_tables ORDER BY table_name").map{ |r| r['TABLE_NAME'] }
             mv = execute("SELECT OBJECT_NAME FROM user_objects WHERE OBJECT_TYPE = 'MATERIALIZED VIEW'").map{ |r| r['OBJECT_NAME'] }
             tables - mv
         end
         
         def get_table_create_sql(table)
             sql = nil
             connection do |c|
                 out = nil
                 cursor = c.parse('BEGIN :out1 := DBMS_METADATA.GET_DDL(object_type=>:in1, name=>:in2); END;')
                 cursor.bind_param(1, out, OCI8::CLOB)
                 cursor.bind_param(2, 'TABLE', String)
                 cursor.bind_param(3, table, String)
                 res = cursor.exec
                 sql = cursor[1].read
                 cursor.close
                 # cursor = c.parse('BEGIN DBMS_METADATA_UTIL.LOAD_STYLESHEETS(); END;')
                 # cursor.exec
             end
             sql
         end
         
         def dump(stream, tables=nil)
             stream << "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';\n\n"
             super(stream, tables)
         end
         
         def dump_table_data(table, stream)
             connection do |c|
                 cursor = c.parse("SELECT COUNT(*) AS N FROM #{table}")
                 cursor.exec
                 num = cursor.fetch[0]
                 cursor.close
                 cursor = c.parse("select * from #{table}")
                 cursor.exec
                 if num > 0
                     info = describe_table(table)
                     fields = info[:columns]
                     stream << "INSERT INTO #{table} (#{info[:order].map{ |f| "#{f}"}.join(', ')})\n"
                     stream << "VALUES\n"
                     cnt = 0
                     while row = cursor.fetch
                         cnt += 1
                         stream << "("
                         info[:order].each_with_index do |f, i|
                             stream << dump_value(row[i], fields[f])
                             stream << ", " if i < fields.length - 1
                         end
                         stream << ")"
                         if cnt < num
                             stream << ",\n"
                         else
                             stream << ";\n"
                         end
                     end
                     stream << "\n\n"
                 end
                 cursor.close
             end
         end
         
         def dump_value(val, field)
             return 'NULL' if val.nil?
             type =  field[:type]
             if ['CHAR', 'VARCHAR', 'VARCHAR2', 'BLOB', 'CLOB'].include?(type)
                 val = val.gsub("'", "''").gsub("\n", '\n').gsub("\r", '\r')
                 return "'#{val}'"
             elsif ['DATE', 'TIME', 'DATETIME'].include?(type)
                 val = val.strftime("%Y-%m-%d %H:%M:%S")
                 return "'#{val}'"
             else
                 return val.to_s
             end
         end

         def describe_table(table)
             primary_keys = []
             o_foreign_keys = {}
             columns = {}
             order = []
             connection do |conn|
                 cols = do_describe_table(conn, table)
                 cols.each do |col|
                     columns[col[:name]] = col
                     order << col[:name]
                 end
                 res = execute("SELECT cols.table_name, cols.COLUMN_NAME, cols.position, cons.status, cons.owner
                 FROM user_constraints cons, user_cons_columns cols
                 WHERE cons.constraint_type = 'P'
                 AND cons.constraint_name = cols.constraint_name
                 AND cols.table_name = '#{table}'".split("\n").join(' '))
                 res.each do |h|
                     primary_keys << h['COLUMN_NAME']
                 end
                 res = execute("SELECT cons.constraint_name as CONSTRAINT_NAME, cols.column_name as REFERENCED_COLUMN,
                 cols.table_name as REFERENCED_TABLE, cons.column_name as COLUMN_NAME
                 FROM user_tab_columns col
                     join user_cons_columns cons
                       on col.table_name = cons.table_name 
                      and col.column_name = cons.column_name
                     join user_constraints cc 
                       on cons.constraint_name = cc.constraint_name
                     join user_cons_columns cols 
                       on cc.r_constraint_name = cols.constraint_name 
                      and cons.position = cols.position
                 WHERE cc.constraint_type = 'R'
                 AND cons.table_name = '#{table}'".split("\n").join(' '))
                 res.each do |h|
                     fk_name = h['CONSTRAINT_NAME']
                     o_foreign_keys[fk_name] ||= {:table => h['REFERENCED_TABLE'], :columns => {}}
                     o_foreign_keys[fk_name][:columns][h['COLUMN_NAME']] = h['REFERENCED_COLUMN']
                 end
             end
             foreign_keys = []
             o_foreign_keys.each do |fk_name, fk_hash|
                 foreign_keys << ForeignKeyConstraint.new(fk_name, fk_hash[:table], fk_hash[:columns])
             end
             return {:columns => columns, :order => order, :primary_keys => primary_keys, :foreign_key_constraints => foreign_keys}

         end

         
         # Schema methods
         
         def column_type(type, attributes)
             case type.name
             when 'String'
                 'VARCHAR2'
             when 'Spider::DataTypes::Text'
                 'CLOB'
             when 'Fixnum'
                 'NUMBER'
             when 'Float'
                 'FLOAT'
             when 'Date', 'DateTime'
                 'DATE'
             when 'Spider::DataTypes::Binary'
                 'BLOB'
             when 'Spider::DataTypes::Bool'
                 'NUMBER'
             end
         end
         
         def column_attributes(type, attributes)
             db_attributes = super(type, attributes)
             case type.name
             when 'String'
                 db_attributes[:length] = attributes[:length] || 255
             when 'Fixnum'
                 db_attributes[:precision] = attributes[:precision] || 38
                 db_attributes[:length] = nil
             when 'Float'
                 # FIXME
                 db_attributes[:precision] = attributes[:precision] if (attributes[:precision])
             when 'Spider::DataTypes::Bool'
                 db_attributes[:precision] = 1
                 db_attributes[:length] = nil
             end
             return db_attributes
         end
         
         def table_name(name)
             table_name = name.to_s.gsub('::', '_')
             return shorten_identifier(table_name, 30).upcase
         end
         
         def column_name(name)
             shorten_identifier(super, 30).upcase
         end
         
         def sequence_name(name)
             shorten_identifier(name, 30).upcase
         end
         
         def foreign_key_name(name)
             shorten_identifier(super, 30)
         end
         
         def schema_field_varchar2_equal?(current, field)
             # FIXME: can't find the length
             return true
         end
         
         def schema_field_number_equal?(current, field)
             # FIXME: where is the precision?
             return true
         end
         
         class OracleNilValue
             attr_accessor :type

             def initialize(type)
                 @type = type
                 @type = Fixnum if @type == TrueClass || @type == FalseClass
             end

             def to_s
                 'NULL'
             end

         end
         
        
    end
    

    

    
    ###############################
    #   Exceptions                #
    ###############################
    
    class OracleException < RuntimeError
    end
    
end; end; end; end
