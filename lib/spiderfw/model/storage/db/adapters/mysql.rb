require 'spiderfw/model/storage/db/db_storage'
require 'mysql'

module Spider; module Model; module Storage; module Db
    
    class Mysql < DbStorage
        attr_reader :last_insert_id
        
        def self.base_types
            super << Spider::DataTypes::Binary
        end
        
        @capabilities = {
            :autoincrement => true,
            :sequences => false,
            :transactions => true
        }
        @reserved_keywords = superclass.reserved_keywords
        @safe_conversions = {
            'CHAR' => ['VARCHAR', 'CLOB'],
            'VARCHAR' => ['CLOB'],
            'NUMBER' => ['VARCHAR']
        }
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
            254 => 'STRING',
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
        
        def disconnect
            begin
                @conn.autocommit(true) if @conn
                super
            rescue
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
        
        def parse_url(url)
            # db:mysql://<username:password>@<host>:<port>/<database>
            if (url =~ /.+:\/\/(?:(.+):(.+)@)?(.+)?\/(.+)/)
                @user = $1
                @pass = $2
                @location = $3
                @db_name = $4
            else
                raise ArgumentError, "Mysql url '#{url}' is invalid"
            end
            if (@location =~ /localhost:(\/.+)/)
                @host = 'localhost'
                @sock = $1
            else
                @location =~ /(.+)(?::(\d+))/
                @host = $1
                @port = $2
            end
            @connection_params = [@host, @user, @pass, @db_name, @port, @sock]
        end
        
        def start_transaction
            connection.autocommit(false)
            @in_transaction = true
        end
        
        def in_transaction?
            return @in_transaction ? true : false
        end
        
        def commit
            @conn.commit if @conn
            disconnect
        end
        
        def rollback
            @conn.rollback
            disconnect
        end
        
        def execute(sql, *bind_vars)
            begin
                if (bind_vars && bind_vars.length > 0)
                    debug_vars = bind_vars.map{|var| var = var.to_s; var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}
                end
                @last_executed = [sql, bind_vars]
                if (Spider.conf.get('storage.db.replace_debug_vars'))
                    cnt = -1
                    debug("mysql executing: "+sql.gsub('?'){ debug_vars[cnt+=1] })
                else
                    debug_vars_str = debug_vars ? debug_vars.join(', ') : ''
                    debug("mysql executing:\n#{sql}\n[#{debug_vars_str}]")
                end
                @stmt = connection.prepare(sql)
                res = @stmt.execute(*bind_vars)
                have_result = (@stmt.field_count == 0 ? false : true)
                if (have_result)
                    result_meta = @stmt.result_metadata
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
                    if (@last_query_type == :select)
                        rows_res = connection.query("select FOUND_ROWS()")
                        @total_rows = rows_res.fetch_row[0].to_i
                    end
                end
                @last_insert_id = connection.insert_id
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
                disconnect
                if (exc.message =~ /Duplicate entry/)
                    raise Spider::Model::Storage::DuplicateKey
                else
                    raise exc
                end
            ensure
                disconnect if @conn && !in_transaction?
            end
         end
         
         def prepare(sql)
             debug("mysql preparing: #{sql}")
             return @stmt = connection.prepare(sql)
         end

         def execute_statement(stmt, *bind_vars)
             stmt.execute(*bind_vars)
         end
         
         def total_rows
             return @total_rows
         end
         
         def prepare_value(type, value)
             value = super(type, value)
             return value unless value
             case type.name
             when 'Date', 'DateTime'
                 return value.strftime("%Y-%m-%dT%H:%M:%S")
             when 'Fixnum'
                 return value.to_i
             end
             return value
         end
         
         def value_to_mapper(type, value)
             return unless value
             case type.name
             when 'DateTime'
                 @@time_offset ||= DateTime.now.offset
                 return type.civil(value.year, value.month, value.day, value.hour, value.minute, value.second, @@time_offset)
             when 'Date'
                 return type.civil(value.year, value.month, value.day)
             end
             return super(type, value)
         end
         
         ##############################################################
         #   SQL methods                                              #
         ##############################################################         
         
         
         def sql_select(query)
             @last_query_type = :select
             bind_vars = query[:bind_vars] || []
             tables_sql, tables_values = sql_tables(query)
             sql = "SELECT "
             sql += "SQL_CALC_FOUND_ROWS " unless query[:query_type] == :count
             sql += "#{sql_keys(query)} FROM #{tables_sql} "
             bind_vars += tables_values
             where, vals = sql_condition(query)
             bind_vars += vals
             sql += "WHERE #{where} " if where && !where.empty?
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
             connection do |c|
                 res = c.query("select * from #{table} where 1=0")
                 fields = res.fetch_fields
                 fields.each do |f|
                     type =  self.class.field_types[f.type]
                     length = f.length;
                     length /= 3 if (type == 'VARCHAR')
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
                     primary_keys << f.name if f.is_pri_key?
                 end                 
                 res = c.query("select * from INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE constraint_schema = '#{@db_name}' and table_name = '#{table}'")
                 while h = res.fetch_hash
                     fk_table = h['REFERENCED_TABLE_NAME']
                     if fk_table
                         fk_fields1 = h['COLUMN_NAME'].split(',')
                         fk_fields2 = h['REFERENCED_COLUMN_NAME'].split(',')
                         fk_name = h['CONSTRAINT_NAME']
                         fk_name = $1 if fk_name =~ /^FK_(.+)/
                         fk_fields = {}
                         fk_fields1.each_index{ |i| fk_fields[fk_fields1[i]] = fk_fields2[i] }
                         foreign_keys << ForeignKeyConstraint.new(fk_name, fk_table, fk_fields)
                     end
                 end
                 
             end
             return {:columns => columns, :primary_keys => primary_keys, :foreign_key_constraints => foreign_keys}
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
             when 'Date', 'DateTime'
                 'DATETIME'
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
             return db_attributes
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
             
             def generate_schema(schema=nil)
                 schema = super
                 autoincrement = schema.columns.select{ |k, v| v.attributes[:autoincrement] }
                 keep = autoincrement.select{ |k, v| @model.elements[k].primary_key? }.map{ |v| v[0] }
                 keep = [] if keep.length > 1
                 #keep = autoincrement[0] if (keep.length != 1)
                 autoincrement.each do |k, v|
                     next if k == keep[0]
                     v.attributes[:autoincrement] = false
                     schema.set_sequence(k, @storage.sequence_name("#{schema.table}_#{k}"))
                 end
                 return schema
             end
             
             def do_insert(obj)
                 super
                 schema.columns.select{ |k, v| v.attributes[:autoincrement] }.each do |k, v| # should be one
                     obj.set_loaded_value(k, storage.last_insert_id)
                 end
             end
             
         end
        
    end
    
end; end; end; end
