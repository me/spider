require 'spiderfw/model/storage/db/db_storage'
require 'oci8'

module Spider; module Model; module Storage; module Db
    
    class OCI8 < DbStorage
        @capabilities = {
            :autoincrement => false,
            :sequences => true,
            :transactions => true
        }
        @reserved_keywords = superclass.reserved_keywords + ['oci8_row_num']
        @safe_conversions = {
            'CHAR' => ['VARCHAR', 'CLOB'],
            'VARCHAR' => ['CLOB'],
            'NUMBER' => ['VARCHAR']
        }
        @map_types = {
            'text' => String,
            'longText' => String,
            'int' => Fixnum,
            'real' => Float,
            'dateTime' => DateTime
        }
        class << self; attr_reader :reserved_kewords, :safe_conversions, :map_types end
        
        @connection_semaphore = Mutex.new
        @connections = {}
        
        def self.get_connection(user, pass, dbname, role)
            @connection_semaphore.synchronize{
                conn_params = [user, pass, dbname, role]
                @connections[conn_params] ||= []
                if (@connections[conn_params].length > 0)
                     # TODO: mantain a pool instead of a single connection
                    return @connections[conn_params][0]
                end
                conn = ::OCI8.new(*conn_params)
                # FIXME!!!! It is shared now!
                conn.autocommit = true
                @connections[conn_params] << conn
                return conn
            }
            
            
        end
        
        def self.disconnect(connection)
        end
        
        

        
        def parse_url(url)
            # db:oracle://<username/password>:connect_role@<database>
            # where database is
            # the net8 connect string or
            # for Oracle client 10g or later, //hostname_or_ip:port_no/oracle_sid
            if (url =~ /.+:\/\/(?:(.+):(.+)(?::(.+))?@)?(.+)/)
                @user = $1
                @pass = $2
                @role = $3
                @dbname = $4
            else
                raise ArgumentError, "OCI8 url '#{url}' is invalid"
            end
        end
        
        def connect()
            @conn = self.class.get_connection(@user, @pass, @dbname, @role)
        end
        
        def connected?
            @conn != nil
        end
        
        def connection
            connect unless connected?
            @conn
        end
        
        def disconnect
            self.class.disconnect(@conn)
            @conn = nil
        end
        
        def supports_transactions?
            return true
        end
        
        def start_transaction
            connection.autocommit = false
        end
        
        def in_transaction?
            return @conn.autocommit?
        end
        
        def commit
            @conn.commit
            disconnect
        end
        
        def rollback
            @conn.rollback
            disconnect
        end
        
        def prepare_value(type, value)
            return OCI8NilValue.new(type) if (value == nil)
            case type
            when 'binary'
                return OCI8::BLOB.new(@conn, value)
            end
            return value
        end
        
        def value_for_condition(type, value)
            return value if value.nil?
            super
        end
        
        def value_to_mapper(type, value)
            case type
            when 'dateTime'
                return value ? value.to_date : nil
            when 'longText'
                return value ? value.read : ''
            else
                return value
            end
        end

         def execute(sql, *bind_vars)
             if (bind_vars && bind_vars.length > 0)
                 debug_vars = bind_vars.map{|var| var = var.to_s; var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}.join(', ')
             end
             @last_executed = [sql, bind_vars]
             debug("oci8 executing:\n#{sql}\n[#{debug_vars}]")
             @cursor = connection.parse(sql)
             return @cursor if (!@cursor || @cursor.is_a?(Fixnum))
             bind_vars.each_index do |i|
                 var = bind_vars[i]
                 if (var.is_a?(OCI8NilValue))
                     @cursor.bind_param(i+1, nil, var.type, 0)
                 else
                     @cursor.bind_param(i+1, var)
                 end
             end
             res = @cursor.exec
             return res unless @cursor.type == ::OCI8::STMT_SELECT
            # @cursor = connection.exec(sql, *bind_vars)
             result = []
             while (h = @cursor.fetch_hash)
                 if block_given?
                      yield h
                  else
                      result << h
                  end
             end
             disconnect unless in_transaction?
             unless block_given?
                 result.extend(StorageResult)
                 @last_result = result
                 return result
             end
         end
         

         def prepare(sql)
             debug("oci8 preparing: #{sql}")
             return @cursor = connection.parse(sql)
         end

         def execute_statement(stmt, *bind_vars)
             stmt.exec(bind_vars)
         end
         
         def total_rows
             #return @cursor.row_count
             return nil unless @last_executed
             q = @last_query.clone
             unless (q[:offset] || q[:limit])
                 return @last_result ? @last_result.length : nil
             end
             q.delete(:offset); q.delete(:limit)
             sql, vars = sql_select(q)
             res = execute("SELECT COUNT(*) AS N FROM (#{sql})", *vars)
             return nil unless res && res[0]
             return res[0]['N']
         end
         
         def sequence_next(sequence_name)
             res = execute("SELECT #{sequence_name}.NEXTVAL AS NEXT FROM DUAL")
             return res[0]['NEXT'].to_i
         end

         
         ##############################################################
         #   SQL methods                                              #
         ##############################################################
         
         # def sql_keys(query)
         #     query[:keys].map{ |key|
         #         if (query[:types][key] == 'dateTime')
         #             as = key.split('.')[-1]
         #             "TO_CHAR(#{key}, 'yyyy-mm-dd hh24:mi') AS #{as}"
         #         else
         #             key
         #         end
         #     }.join(', ')
         # end
         
         def sql_select(query)
             @bind_cnt = 0
             # Spider::Logger.debug("SQL SELECT:")
             # Spider::Logger.debug(query)
             bind_vars = query[:bind_vars] || []
             if query[:limit] # Oracle is so braindead
                 query[:order] << [query[:keys][0], 'desc'] if query[:order].length < 1
                 query[:order].each do |o|
                     field, direction = o
                     i = query[:keys].index(field)
                     unless i
                         query[:keys].push(field)
                         i = query[:keys].length < 1
                     end
                     query[:keys] << "#{field} AS #{field.sub('.', '_')}"
                 end
             end
             keys = sql_keys(query)
             order = sql_order(query)
             if (query[:limit])
                 keys += ", row_number() over (order by #{order}) oci8_row_num"
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
                     limit = "oci8_row_num between :#{@bind_cnt+=1} and :#{@bind_cnt+=1}"
                     bind_vars << query[:offset]
                     bind_vars << query[:offset] + query[:limit]
                 else
                     limit = "oci8_row_num < :#{@bind_cnt+=1}"
                     bind_vars << query[:limit]
                 end
                 sql = "SELECT * FROM (#{sql}) WHERE #{limit} order by #{order.gsub('.', '_')}"
             else
                 sql += "ORDER BY #{order} " if order && !order.empty?
             end
             return sql, bind_vars
         end
         
         def sql_limit(query)
             # already done in sql_condition
         end
         
         def sql_condition_value(key, comp, value)
             if (comp.to_s.downcase == 'ilike')
                 comp = 'like'
                 key = "UPPER(#{key})"
             end
             if (value.nil?)
                 comp = comp == '=' ? "IS" : "IS NOT"
                 sql = "#{key} #{comp} NULL"
             else
                 sql = "#{key} #{comp} :#{(@bind_cnt += 1)}"
                 sql += " AND :#{(@bind_cnt += 1)}" if comp.to_s.downcase == 'between'
             end
             return sql
         end
         
         def sql_insert(insert)
             @bind_cnt = 0
             keys = insert[:values].keys.join(', ')
             vals = insert[:values].values.map{":#{(@bind_cnt += 1)}"}
             vals = vals.join(', ')
             sql = "INSERT INTO #{insert[:table]} (#{keys}) " +
                   "VALUES (#{vals})"
             return [sql, insert[:values].values]
         end
         
         def sql_insert_values(insert)
             insert[:values].values.map{":#{(@bind_cnt += 1)}"}.join(', ')
         end
         
         def sql_update(query)
             @bind_cnt = 0
             super
         end
         
         def sql_update_values(update)
             update[:values].map{ |k, v| 
                 "#{k} = :#{(@bind_cnt += 1)}"
             }.join(', ')
         end
         
         def sql_delete(del)
             @bind_cnt = 0
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
         
         def create_sequence(sequence_name)
             execute("create sequence #{sequence_name}")
         end
         
         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################

         def list_tables
             return execute("SELECT table_name FROM user_tables ORDER BY table_name").flatten
         end

         def describe_table(table)
             columns = {}
             t = connection.describe_table(table)
             t.columns.each do |c|
                 col = {
                     :type => c.data_type.to_s.upcase,
                     :length => c.data_size,
                     :precision => c.precision,
                     :scale => c.scale,
                     :null => c.nullable?
                 }
                 col.delete(:length) if (col[:precision])
                 columns[c.name] = col
             end
             return columns
         end

         def table_exists?(table)
             begin
                 connection.describe_table(table)
                 Spider.logger.debug("TABLE EXISTS #{table}")
                 return true
             rescue OCIError
                 return false
             end
         end
         
         # Schema methods
         
         def column_type(type, attributes)
             case type
             when 'text'
                 'VARCHAR2'
             when 'longText'
                 'CLOB'
             when 'int'
                 'NUMBER'
             when 'real'
                 'FLOAT'
             when 'dateTime'
                 'DATE'
             when 'binary'
                 'BLOB'
             when 'bool'
                 'NUMBER'
             end
         end
         
         def column_attributes(type, attributes)
             db_attributes = super(type, attributes)
             case type
             when 'text'
                 db_attributes[:length] = attributes[:length] || 255
             when 'longText'
                 db_attributes[:length] = attributes[:length] if (attributes[:length])
             when 'int'
                 db_attributes[:precision] = attributes[:precision] || 38
                 db_attributes[:length] = nil
             when 'real'
                 # FIXME
                 db_attributes[:precision] = attributes[:precision] if (attributes[:precision])
             when 'binary'
                 db_attributes[:length] = attributes[:length] if (attributes[:length])
             when 'bool'
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
             super.upcase
         end
         
         def sequence_name(name)
             shorten_identifier(name, 30).upcase
         end
         
        
    end
    
    class OCI8NilValue
        attr_accessor :type
        
        def initialize(type)
            @type = (mapped = OCI8.map_types[type]) ? mapped : type
        end
        
        def to_s
            'NULL'
        end
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class OCI8Exception < RuntimeError
    end
    
end; end; end; end