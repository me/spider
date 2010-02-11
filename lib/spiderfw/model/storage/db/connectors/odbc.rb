require 'odbc'

module Spider; module Model; module Storage; module Db; module Connectors
    
    module ODBC
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        module ClassMethods
        
            def new_connection(dsn=nil, user=nil, passwd=nil)
                conn = ::ODBC.connect(dsn, user, passwd)
                conn.autocommit = true
                return conn
            end
        
            def connection_alive?(conn)
                begin
                    return conn.connected?
                rescue
                    return false
                end 
            end
            
        end
        
        def release
            begin
                @conn.autocommit = true if @conn
                super
            rescue
                self.class.remove_connection(@conn, @connection_params)
                @conn = nil
            end
        end
        
        def parse_url(url)
            # adapter//<username:password>@<dsn>
            if (url =~ /(.+):\/\/(?:(.+):(.+)@)?(.+)/)
                @adapter = $1
                @user = $2
                @pass = $3
                @dsn = $4
            else
                raise ArgumentError, "ODBC url '#{url}' is invalid"
            end
            @connection_params = [@dsn, @user, @pass]
        end
        
        def start_transaction
            connection.autocommit = false
            @in_transaction = true
        end
        
        def in_transaction?
            return @in_transaction ? true : false
        end
        
        def commit
            @conn.commit if @conn
            release
        end
        
        def rollback
            @conn.rollback
            release
        end
        
        def execute(sql, *bind_vars)
            begin
                if (bind_vars && bind_vars.length > 0)
                    debug_vars = bind_vars.map{|var| var = var.to_s; var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}
                end
                @last_executed = [sql, bind_vars]
                if (Spider.conf.get('storage.db.replace_debug_vars'))
                    cnt = -1
                    debug("odbc executing: "+sql.gsub('?'){ debug_vars[cnt+=1] })
                else
                    debug_vars_str = debug_vars ? debug_vars.join(', ') : ''
                    debug("odbc executing:\n#{sql}\n[#{debug_vars_str}]")
                end
                @stmt = connection.prepare(sql)
                res = @stmt.execute(*bind_vars)
                have_result = (@stmt.ncols != 0)
                if (have_result)
                    result = []
                    while (h = res.fetch_hash)
                        if block_given?
                            yield h
                        else
                            result << h
                        end
                    end
                end
                @stmt.drop
                if (@last_query_type == :insert)
                    res = conn.run("SELECT @@IDENTITY AS NewID")
                    @last_insert_id = res.fetch[0]
                end
                @last_query_type = nil
                if (have_result)
                    unless block_given?
                        result.extend(StorageResult)
                        return result
                    end
                else
                    return res
                end
            rescue => exc
                release
                raise exc
            ensure
                @stmt.drop if @stmt
                release if @conn && !in_transaction?
            end
         end
         
         def prepare(sql)
             return @stmt = connection.prepare(sql)
         end
         
         def execute_statement(stmt, *bind_vars)
              stmt.execute(*bind_vars)
         end
         
         
         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################

         def list_tables
             connection do |c|
                 res = c.tables
                 tables = []
                 res.each do |a|
                     tables << a[2]
                 end
                 res.drop
                 return tables
             end
         end

         def describe_table(table)
             columns = {}
             connection do |c|
                 fields = c.columns(table)
                 fields.each_hash do |f|
                     name = f['COLUMN_NAME']
                     type =  f['TYPE_NAME']
                     length = f['LENGTH'];
                     scale = nil
                     precision = f['PRECISION']
                     col = {
                         :type => type,
                         :length => length,
                         :precision => precision,
                         :scale => scale
                     }
                     col = parse_db_column(col)
                     columns[name] = col
                 end
                 fields.drop
                 pks = c.primary_keys(table)
                 pks.each_hash do |pk|
                     columns[pk['COLUMN_NAME']][:primary_key] = true
                 end
                 pks.drop
                 indexes = {}
                 inds = c.indexes(table)
                 inds.each_hash do |ind|
                     name = ind['INDEX_QUALIFIER']
                     next unless name
                     indexes[name] = ind['COLUMN_NAME']
                 end
                 inds.drop
             end
             
             return {:columns => columns}
         end
         
         def value_to_mapper(type, value)
             return unless value
             case type.name
             when 'DateTime'
                 begin
                     return ::ODBC.to_time(value).to_datetime
                 rescue ArgumentError => exc
                     @@time_offset ||= DateTime.now.offset
                     return DateTime.civil(value.year, value.month, value.day, value.hour, value.minute, value.second, @@time_offset)
                 end
             when 'Date'
                 return ::ODBC.to_date(value)
             end
             return super(type, value)
         end

         def table_exists?(table)
             connection do |c|
                 cols = c.columns(table)
                 res = cols.fetch ? true : false
                 cols.drop
             end
             Spider.logger.debug("TABLE EXISTS #{table}") if res
             return res
         end
        
    end
    
    
    
end; end; end; end; end