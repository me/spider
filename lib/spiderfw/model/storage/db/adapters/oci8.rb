require 'spiderfw/model/storage/db/db_storage'
require 'oci8'

module Spider; module Model; module Storage; module Db
    
    class OCI8 < DbStorage
        @capabilities = {
            :autoincrement => false,
            :sequences => true,
            :transactions => true
        }
        
        @semaphore = Mutex.new
        @connections = {}
        
        def self.get_connection(user, pass, dbname, role)
            @semaphore.synchronize{
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
        
        
        @reserved_keywords = superclass.reserved_keywords + []
        @safe_conversions = {
            'CHAR' => ['VARCHAR', 'CLOB'],
            'VARCHAR' => ['CLOB'],
            'NUMBER' => ['VARCHAR']
        }
        class << self; attr_reader :reserved_kewords, :safe_conversions end
        
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
             case type
             when 'binary'
                 return OCI8::BLOB.new(@conn, value)
             end
             return value
         end

         def execute(sql, *bind_vars)
             if (bind_vars && bind_vars.length > 0)
                 debug_vars = bind_vars.map{|var| var = var.to_s; var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}.join(', ')
             end
             @last_executed = [sql, bind_vars]
             debug("oci8 executing:\n#{sql}\n[#{debug_vars}]")
             result = []
             @cursor = connection.exec(sql, *bind_vars)
             return @cursor if (!@cursor || @cursor.is_a?(Fixnum))
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
             q = @last_query
             unless (q[:offset] || q[:limit])
                 return @last_result ? @last_result.length : nil
             end
             res = execute("SELECT COUNT(*) AS N FROM (#{@last_executed[0]})", *@last_executed[1])
             return nil unless res && res[0]
             return res[0]['N']
         end
         
         def sequence_next(table, field)
             sn = sequence_name(table, field)
             res = execute("SELECT #{sn}.NEXTVAL AS NEXT FROM DUAL")
             return res[0]['NEXT'].to_i
         end

         
         ##############################################################
         #   SQL methods                                              #
         ##############################################################
         
         def sql_keys(query)
             query[:keys].map{ |key|
                 debugger unless query[:types].is_a?(Hash)
                 if (query[:types][key] == 'dateTime')
                     as = key.split('.')[-1]
                     "TO_CHAR(#{key}, 'yyyy-mm-dd hh24:mi') AS #{as}"
                 else
                     key
                 end
             }.join(', ')
         end
         
         def sql_select(query)
             @bind_cnt = 0
             super
         end
         
         def sql_condition(query)
             where, vals = super
             if (query[:limit])
                 if (query[:offset])
                     limit_cond = "ROWNUM BETWEEN #{query[:offset]} AND #{query[:offset]+query[:limit]}"
                 else
                     limit_cond = "ROWNUM < #{query[:limit]}"
                 end
                 if (where && !where.empty?)
                     where = "(#{where}) AND (#{limit_cond})"
                 else
                     where = limit_cond
                 end
             end
             return [where, vals]
         end
         
         def sql_limit(query)
             # already done in sql_condition
         end
         
         def sql_condition_value(key, comp, value)
             if (comp.to_s.downcase == 'ilike')
                 comp = 'like'
                 key = "UPPER(#{key})"
             end
             "#{key} #{comp} :#{(@bind_cnt += 1)}"
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

         
         def create_table(create)
             super(create)
             check_sequences(create[:table], create[:fields].select{|f| f[:attributes][:autoincrement]})
         end
         
         def alter_table(alter)
             super(alter)
             check_sequences(alter[:table], alter[:all_fields].select{|f| f[:attributes][:autoincrement]})
         end
         
         def sql_alter_field(table_name, name, type, attributes)
             ["ALTER TABLE #{table_name} MODIFY #{sql_table_field(name, type, attributes)}"]
         end

         def check_sequences(table, fields)
             fields.each do |field|
                 sequence_name = sequence_name(table, field[:name])
                 check = "select SEQUENCE_NAME from user_sequences where sequence_name = :1"
                 res = execute(check, sequence_name)
                 unless res[0]
                     execute("create sequence #{sequence_name}")
                 end
             end
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
                 columns[c.name] = {
                     :type => c.data_type.to_s.upcase,
                     :length => c.data_size,
                     :precision => c.precision,
                     :null => c.nullable?
                 }
                 columns[c.name].delete(:length) if (columns[c.name][:precision])
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
             when 'bool'
             when 'int'
                 db_attributes[:precision] = attributes[:precision] || 38
             when 'real'
                 # FIXME
                 db_attributes[:precision] = attributes[:precision] if (attributes[:precision])
             when 'binary'
                 db_attributes[:length] = attributes[:length] if (attributes[:length])
             when 'bool'
                 db_attributes[:precision] = 1
             end
             return db_attributes
         end
         
         def table_name(name)
             table_name = name.to_s.gsub('::', '_')
             return shorten_identifier(table_name, 30).upcase
         end
         
         def shorten_identifier(name, length)
             while (name.length > length)
                 parts = name.split('_')
                 max = 0
                 max_i = nil
                 parts.each_index do |i|
                     if (parts[i].length > max)
                         max = parts[i].length
                         max_i = i
                     end
                 end
                 parts[max_i] = parts[max_i][0..-2]
                 name = parts.join('_')
                 name.gsub!('_+', '_')
             end
             return name
         end
         
         def column_name(name)
             super.upcase
         end
         
         def sequence_name(table, field)
             shorten_identifier(table+'_'+field, 30)
         end
         
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class OCI8Exception < RuntimeError
    end
    
end; end; end; end