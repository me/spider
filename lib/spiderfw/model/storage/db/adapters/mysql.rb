require 'spiderfw/model/storage/db/db_storage'
require 'mysql'

module Spider; module Model; module Storage; module Db
    
    class Mysql < DbStorage
        
        def self.base_types
            super << Spider::DataTypes::Binary
        end
        
        @capabilities = {
            :autoincrement => true,
            :sequences => false,
            :transactions => true,
            :foreign_keys => true
        }
        @reserved_keywords = superclass.reserved_keywords + ['interval']
        @safe_conversions = DbStorage.safe_conversions.merge({
            'CHAR' => ['VARCHAR', 'CLOB'],
            'VARCHAR' => ['CLOB'],
            'NUMBER' => ['VARCHAR']
        })
        @type_synonyms = {
            'BLOB' => ['TEXT']
        }
        @field_types = {
            0 => 'DECIMAL',
            1 => 'TINYINT',
            2 => 'SHORT',
            3 => 'INT',
            4 => 'FLOAT',
            5 => 'DOUBLE',
            6 => 'NULL',
            7 => 'TIMESTAMP',
            8 => 'LONGLONG',
            9 => 'INT24',
            10 => 'DATE',
            11 => 'TIME', 
            12 => 'DATETIME',
            13 => 'YEAR',
            14 => 'NEWDATE',
            16 => 'BIT',
            246 => 'DECIMAL',
            247 => 'ENUM',
            248 => 'SET',
            249 => 'TINY_BLOB',
            250 => 'MEDIUM_BLOB',
            251 => 'LONG_BLOB',
            252 => 'BLOB',
            253 => 'VARCHAR',
            254 => 'CHAR',
            255 => 'GEOMETRY'
        }
        @field_flags = {
            :not_null => 1,
            :primary_key => 2,
            :unique_key => 4,
            :multiple_key => 8,
            :blob => 16,
            :unsigned => 32,
            :zerofill => 64,
            :binary => 128,
            :enum => 256,
            :auto_increment => 512,
            :timestamp => 1024,
            :set => 2048,
            :num => 32768,
            :part_key => 16384,
            :group => 32768,
            :unique => 65536
        }

        class << self; attr_reader :reserved_kewords, :type_synonyms, :safe_conversions, :field_types, :field_flags end
        
        def self.new_connection(host=nil, user=nil, passwd=nil, db=nil, port=nil, sock=nil, flag=nil)
            conn = ::Mysql.new(host, user, passwd, db, port, sock, flag)
            conn.autocommit(true)
            conn.query("SET NAMES 'utf8'")
            return conn
        end
        
        def self.disconnect(conn)
            conn.close
        end
        
        def configure(conf)
            super
            @configuration['default_engine'] ||= Spider.conf.get('db.mysql.default_engine')
        end
        
        def release
            begin
                #Spider::Logger.debug("MYSQL #{self.object_id} in thread #{Thread.current} releasing connection #{@conn}")
                @conn.autocommit(true) if @conn && !Spider.conf.get('storage.db.shared_connection')
                super
            rescue => exc
                Spider::Logger.error("MYSQL #{self.object_id} in thread #{Thread.current} exception #{exc.message} while trying to release connection #{@conn}")
                self.class.remove_connection(@conn, @connection_params)
                @conn = nil
            end
        end
        
        def self.connection_alive?(conn)
            begin
                return conn.ping
            rescue
                return false
            end 
        end
        
        def self.parse_url(url)
            # db:mysql://<username:password>@<host>:<port>/<database>
            if (url =~ /.+:\/\/(?:(.+):(.+)@)?(.+)?\/(.+)/)
                user = $1
                pass = $2
                location = $3
                db_name = $4
            else
                raise ArgumentError, "Mysql url '#{url}' is invalid"
            end
            if (location =~ /localhost:(\/.+)/)
                host = 'localhost'
                sock = $1
            else
                location =~ /(.+)(?::(\d+))/
                host = $1
                port = $2
            end
            return [host, user, pass, db_name, port, sock]
        end
        
        def parse_url(url)
            @host, @user, @pass, @db_name, @port, @sock = self.class.parse_url(url)
            @connection_params = [@host, @user, @pass, @db_name, @port, @sock]
        end
        
        def do_start_transaction
            connection.autocommit(false)
            curr[:in_transaction] = true
        end
        
        def savepoint(name)
            connection.query("SAVEPOINT #{name}")
            super
        end
        
        def in_transaction?
            return curr[:in_transaction] ? true : false
        end
        

        def do_commit
            curr[:conn].commit if curr[:conn]
            curr[:in_transaction] = false
        end
        
        def do_rollback
            curr[:conn].rollback if curr[:conn]
            curr[:in_transaction] = false
        end
        
        def rollback_savepoint(name=nil)
            connection.query("ROLLBACK TO #{name}")
            super
        end
        
        def execute(sql, *bind_vars)
            begin
                if (bind_vars && bind_vars.length > 0)
                    debug_vars = bind_vars.map{|var| var = var.to_s; var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}
                end
                curr[:last_executed] = [sql, bind_vars]
                if (Spider.conf.get('storage.db.replace_debug_vars'))
                    cnt = -1
                    debug("mysql #{curr[:conn]} executing: "+sql.gsub('?'){ debug_vars[cnt+=1] })
                else
                    debug_vars_str = debug_vars ? debug_vars.join(', ') : ''
                    debug("mysql #{curr[:conn]} executing:\n#{sql}\n[#{debug_vars_str}]")
                end
                query_start
                stmt = connection.prepare(sql)
                curr[:stmt] = stmt
                res = stmt.execute(*bind_vars)
                have_result = (stmt.field_count == 0 ? false : true)
                if (have_result)
                    result_meta = stmt.result_metadata
                    fields = result_meta.fetch_fields
                    result = []
                    while (a = res.fetch)
                        h = {}
                        fields.each_index{ |i| h[fields[i].name] = a[i]}
                        if block_given?
                            yield h
                        else
                            result << h
                        end
                    end
                    if (curr[:last_query_type] == :select)
                        rows_res = connection.query("select FOUND_ROWS()")
                        curr[:total_rows] = rows_res.fetch_row[0].to_i
                    end
                end
                curr[:last_insert_id] = connection.insert_id
                curr[:last_query_type] = nil
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
                if (exc.message =~ /Duplicate entry/)
                    raise Spider::Model::Storage::DuplicateKey
                else
                    raise exc
                end
            ensure
                query_finished
                release if curr[:conn] && !in_transaction?
            end
        end
         
        def prepare(sql)
            debug("mysql preparing: #{sql}")
            return curr[:stmt] = connection.prepare(sql)
        end

        def execute_statement(stmt, *bind_vars)
            stmt.execute(*bind_vars)
        end
         
        def total_rows
            return curr[:total_rows]
        end
         
        def prepare_value(type, value)
            value = super(type, value)
            return value unless value
            case type.name
            when 'String'
                return value.to_s
            when 'Date'
                return value.strftime("%Y-%m-%d")
            when 'DateTime'
                return value.strftime("%Y-%m-%dT%H:%M:%S")
            when 'Time'
                return value.strftime("%H:%M:%S")
            when 'Fixnum'
                return value.to_i
            end
            return value
         end
         
        def value_to_mapper(type, value)
            return unless value
            begin
                case type.name
                when 'DateTime'
                    @@time_offset ||= DateTime.now.offset
                    return type.civil(value.year, value.month, value.day, value.hour, value.minute, value.second, @@time_offset)
                when 'Date'
                    return type.civil(value.year, value.month, value.day)
                when 'Time'
                    return type.local(2000, 1, 1, value.hour, value.minute, value.second)
                end
                return super(type, value)    
            rescue 
                return nil    
            end 
        end
         
        def last_insert_id
            curr[:last_insert_id]
        end
         
         ##############################################################
         #   SQL methods                                              #
         ##############################################################         
         
         
         def sql_select(query)
             curr[:last_query_type] = :select
             bind_vars = query[:bind_vars] || []
             tables_sql, tables_values = sql_tables(query)
             sql = "SELECT "
             sql += "SQL_CALC_FOUND_ROWS " unless query[:query_type] == :count
             if query[:joins] && query[:joins].values.map{ |h| h.values }.flatten.select{ |v| v[:type] == :left}.length > 0
                 sql += "DISTINCT "
             end
             sql += "#{sql_keys(query)} FROM #{tables_sql} "
             bind_vars += tables_values
             where, vals = sql_condition(query)

             bind_vars += vals if vals
             sql += "WHERE #{where} " if where && !where.empty?
             having, having_vals = sql_condition(query, true)
             unless having.blank? && query[:group_by].blank?
                group_fields = query[:group_by] || (
                    query[:keys].select{ |k| !k.is_a?(FieldExpression)
                } + collect_having_fields(query[:condition])).flatten.uniq
                group_keys = sql_keys(group_fields)
                sql += "GROUP BY #{group_keys} " 
                sql += "HAVING #{having} " unless having.blank?
                bind_vars += having_vals if having_vals
            end
             order = sql_order(query)
             sql += "ORDER BY #{order} " if order && !order.empty?
             limit = sql_limit(query)
             sql += limit if limit
             return sql, bind_vars
         end
         
         def sql_table_field(name, type, attributes)
             sql = super
             sql += " AUTO_INCREMENT" if attributes[:autoincrement]
             return sql
         end

         def sql_add_field(table_name, name, type, attributes)
             sqls = super
             sqls[0] += ", ADD PRIMARY KEY(#{name})" if attributes[:primary_key]
             sqls
         end

         def sql_alter_field(table_name, name, type, attributes)
             sqls = super
             sqls[0] += ", ADD PRIMARY KEY(#{name})" if attributes[:primary_key]
             sqls
         end
         
         def sql_create_table(create)
             sqls = super
             sqls[0] += " ENGINE=#{@configuration['default_engine']}" if @configuration['default_engine']
             sqls
         end

         def sql_create_primary_key(table_name, fields)
            nil # done in add field or alter field
        end
         
         def function(func)
             return super unless func.func_name == :concat
             fields = func.elements.map{ |func_el|
                 if (func_el.is_a?(Spider::QueryFuncs::Function))
                     function(func_el)
                 else
                     func.mapper_fields[func_el]
                 end
             }
             return "CONCAT(#{fields.map{ |f| "COALESCE(#{f}, '')" }.join(', ')})"
         end
         
         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################

         def list_tables
             connection do |c|
                 return c.list_tables
             end
         end

         def describe_table(table)
             columns = {}
             primary_keys = []
             foreign_keys = []
             order = []
             connection do |c|
                 res = c.query("select * from #{table} where 1=0")
                 fields = res.fetch_fields
                 fields.each do |f|
                     type =  self.class.field_types[f.type]
                     length = f.length;
                     length /= 3 if ['CHAR', 'VARCHAR'].include?(type)
                     scale = nil
                     precision = f.decimals
                     # FIXME
                     if (type == 'DECIMAL')
                         scale = f.decimals
                         precision = length - scale
                         length = 0
                     end
                     col = {
                         :type => type,
                         :length => length,
                         :precision => precision,
                         :scale => scale
                     }
                     flags = f.flags
                     self.class.field_flags.each do |flag_name, flag_val|
                         col[flag_name] = (flags & flag_val == 0) ? false : true
                     end
                     columns[f.name] = col
                     order << f.name
                     primary_keys << f.name if f.is_pri_key?
                 end                 
                 res = c.query("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE constraint_schema = '#{@db_name}' and table_name = '#{table}'")
                 while h = res.fetch_hash
                     fk_table = h['REFERENCED_TABLE_NAME']
                     if fk_table
                         fk_fields1 = h['COLUMN_NAME'].split(',')
                         fk_fields2 = h['REFERENCED_COLUMN_NAME'].split(',')
                         fk_name = h['CONSTRAINT_NAME']
                         fk_fields = {}
                         fk_fields1.each_index{ |i| fk_fields[fk_fields1[i]] = fk_fields2[i] }
                         foreign_keys << ForeignKeyConstraint.new(fk_name, fk_table, fk_fields)
                     end
                 end
                 
             end
             return {:columns => columns, :order => order, :primary_keys => primary_keys, :foreign_key_constraints => foreign_keys}
         end

         def table_exists?(table)
             begin
                 connection do |c|
                     c.query("select * from #{table} where 1=0")
                 end
                 Spider.logger.debug("TABLE EXISTS #{table}")
                 return true
             rescue ::Mysql::Error
                 return false
             end
         end
         
         def get_table_create_sql(table)
             sql = nil
             connection do |c|
                 res = c.query("SHOW CREATE TABLE #{table}")
                 sql = res.fetch_row[1]
             end
             sql
         end
         
         
         def dump_table_data(table, stream)
             connection do |c|
                 res = c.query("select * from #{table}")
                 num = res.num_rows
                 if num > 0
                     fields = res.fetch_fields
                     stream << "INSERT INTO `#{table}` (#{fields.map{ |f| "`#{f.name}`"}.join(', ')})\n"
                     stream << "VALUES\n"
                     cnt = 0
                     while row = res.fetch_row
                         cnt += 1
                         stream << "("
                         fields.each_with_index do |f, i|
                             stream << dump_value(row[i], f)
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
             end
         end
         
         def dump_value(val, field)
             return 'NULL' if val.nil?
             type =  self.class.field_types[field.type]
             if ['CHAR', 'VARCHAR', 'BLOB', 'TINY_BLOB', 'MEDIUM_BLOB', 'LONG_BLOB'].include?(type)
                 val = val.gsub("'", "''").gsub("\n", '\n').gsub("\r", '\r')
                 return "'#{val}'"
             elsif ['DATE', 'TIME', 'DATETIME'].include?(type)
                 return "'#{val}'"
             else
                 return val.to_s
             end
         end
         
         # Schema methods
         
         def table_name(name)
             super.downcase
         end
         
         def column_type(type, attributes)
             case type.name
             when 'String'
                 'VARCHAR'
             when 'Spider::DataTypes::Text'
                 'TEXT'
             when 'Fixnum'
                 'INT'
             when 'Float'
                 'FLOAT'
             when 'Date'
                 'DATE'
             when 'DateTime'
                 'DATETIME'
             when 'Time'
                 'TIME'
             when 'Spider::DataTypes::Binary'
                 'BLOB'
             when 'Spider::DataTypes::Bool'
                 'TINYINT'
             when 'BigDecimal', 'Spider::DataTypes::Decimal'
                 'DECIMAL'
             end
         end
         
         def column_attributes(type, attributes)
             db_attributes = super(type, attributes)
             case type.name
             when 'String'
                 db_attributes[:length] = attributes[:length] || 255
             when 'Fixnum'
                 db_attributes[:length] = 11
             end
             db_attributes[:autoincrement] = false if attributes[:autoincrement] && !attributes[:primary_key]
             return db_attributes
         end
         
         def function(func)
             case func.func_name
             when :rownum
                 "if(@rn, @rn:=@rn+1, @rn:=1)-1"
             else
                 super
             end
         end
         
         def schema_field_int_equal?(current, field)
             # FIXME
             return true
         end
         
         def schema_field_text_equal?(current, field)
             # FIXME
             return true
         end
         
         def schema_field_date_equal?(current, field)
             # FIXME
             return true
         end
         
         def schema_field_datetime_equal?(current, field)
             # FIXME
             return true
         end

         def schema_field_float_equal?(current, field)
             # FIXME
             return true
         end
         
         def schema_field_varchar_equal?(current, field)
             # FIXME
             return true
         end
         
         
         # Mapper extension
         
         module MapperExtension
        
             
             def do_insert(obj)
                 super
                 schema.columns.select{ |k, v| v.attributes[:autoincrement] }.each do |k, v| # should be one
                     obj.set_loaded_value(k, storage.last_insert_id)
                 end
             end
             
         end
        
    end
    
end; end; end; end
