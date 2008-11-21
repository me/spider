require 'spiderfw/model/storage/db/db_storage'
require 'oci8'

module Spider; module Model; module Storage; module Db
    
    class OCI8 < DbStorage
        
        @reserved_keywords = superclass.reserved_keywords + []
        class << self; attr_reader :reserved_kewords; end
        
        def parse_url(url)
            # db:oracle://<username/password>:connect_role@<database>
            # where database is
            # the net8 connect string or
            # for Oracle cliente 10g or later, //hostname_or_ip:port_no/oracle_sid
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
            @conn = ::OCI8.new(@user, @pass, @dbname, @role)
            @conn.autocommit = true
        end
        
        def connected?
            @conn != nil
        end
        
        def disconnect
            @conn.logoff()
            @conn = nil
        end
        
        def prepare_value(type, value)
             case type
             when 'binary'
                 return OCI8::BLOB.new(@conn, value)
             end
             return value
         end
         
         def query(query)
             @last_query = query
             super
         end


         def execute(sql, *bind_vars)
             sql = fix_bind_vars(sql)
             connect unless connected?
             if (bind_vars && bind_vars.length > 0)
                 debug_vars = bind_vars.map{|var| var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}.join(', ')
             end
             debug("oci8 executing:\n#{sql}\n[#{debug_vars}]")
             result = []
             @cursor = @conn.exec(sql, *bind_vars)
             return @cursor if (!@cursor || @cursor.is_a?(Fixnum))
             while (h = @cursor.fetch_hash)
                 if block_given?
                      yield h
                  else
                      result << h
                  end
             end
             unless block_given?
                 result.extend(StorageResult)
                 @last_result = result
                 return result
             end
         end
         

         def prepare(sql)
             sql = fix_bind_vars(sql)
             debug("oci8 preparing: #{sql}")
             connect unless connected?
             return @cursor = @conn.prepare(sql)
         end

         def execute_statement(stmt, *bind_vars)
             stmt.exec(bind_vars)
         end
         
         def total_rows
             return @cursor.row_count
             return nil unless @last_query
             q = @last_query
             unless (q[:offset] || q[:limit])
                 return @last_result ? @last_result.length : nil
             end
             q[:offset] = q[:limit] = nil
             q[:keys] = ["COUNT(*) AS N"]
             res = execute(sql_select(q), q[:bind_vars])
             return res[0]['N']
         end
         
         # FIXME! change the way queries are passed to storage to avoid this
         def fix_bind_vars(sql)
             cnt = 0
             sql.gsub(/\s\?/){ |m| ':'+(cnt+=1).to_s}
         end
         
         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################

         def list_tables
             return execute("SELECT table_name FROM user_tables ORDER BY table_name").flatten
         end

         def describe_table(table)
             columns = {}
             t = OCI8.describe_table(table)
             t.columns.each do |c|
                 columns[c.name] = {
                     :type => c.data_type,
                     :length => c.data_size,
                     :precision => c.precision,
                     :null => c.nullable?
                 }
             end
             return columns
         end

         def table_exists?(table)
             begin
                 stmt = prepare("select * from #{table}")
                 stmt.close
                 return true
             rescue SQLite3::SQLException
                 return false
             end
         end
         
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class OCI8Exception < RuntimeError
    end
    
end; end; end; end