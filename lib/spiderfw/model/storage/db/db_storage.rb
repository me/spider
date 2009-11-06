require 'spiderfw/model/storage/base_storage'
require 'spiderfw/model/mappers/db_mapper'
require 'iconv'

module Spider; module Model; module Storage; module Db
    
    # Represents a DB connection, and provides methods to execute structured queries on it.
    # This is the class that generates the actual SQL; vendor specific extensions may override the 
    # generic SQL methods.
    
    class DbStorage < Storage::BaseStorage
        @reserved_keywords = ['from', 'order', 'where', 'to']
        @type_synonyms = {}
        @safe_conversions = {
            'TEXT' => ['LONGTEXT'],
            'INT' => ['TEXT', 'LONGTEXT', 'REAL'],
            'REAL' => ['TEXT']
        }
        @capabilities = {
            :autoincrement => false,
            :sequences => true,
            :transactions => true
        }

        class << self
            # An Array of keywords that can not be used in schema names.
            attr_reader :reserved_keywords
            # An Hash of DB type equivalents.
            attr_reader :type_synonyms
            # Type conversions which do not lose data. See also #safe_schema_conversion?
            attr_reader :safe_conversions
            # An Hash of DB capabilities. The default is 
            # {:autoincrement => false, :sequences => true, :transactions => true}
            # (The BaseStorage class provides file sequences in case the subclass does not support them.)
            attr_reader :capabilities

            # Returns a new connection. Must be implemented by the subclasses; args are implementation specific.
            def new_connection(*args)
                raise "Unimplemented"
            end
            
            # Returns a connection, drawing from the pool or instantiating a new one.
            # Arguments are passed to the #new_connection method.
            # Pool size is configured with 'storage.db.pool.size'.
            def get_connection(*args)
                @connection_semaphore ||= Mutex.new
                @connections ||= {}
                @free_connections ||= {}
                max_connections = Spider.conf.get('storage.db.pool.size')
                
                conn = nil
                connect_exception = nil
                @connection_semaphore.synchronize{
                    @free_connections[args] ||= []
                    @connections[args] ||= []
                    keep_trying = true
                    while (!conn && keep_trying)
                        if (@free_connections[args].empty?)
                            #Spider::Logger.debug("NO FREE CONNECTION")
                            if @connections[args].length <= max_connections
                                begin
                                    conn = new_connection(*args)
                                    @connections[args] << conn if conn
                                rescue => exc
                                    connect_exception = exc
                                    keep_trying = false
                                end
                                #Spider::Logger.debug("CREATED NEW CONNECTION #{conn}")
                            else
                                sleep_cnt = 0
                                while @free_connections[args].empty? && sleep_cnt < 10000
                                    sleep(0.001)
                                    sleep_cnt += 1
                                end
                                keep_trying = false if sleep_cnt == 10000
                                #Spider::Logger.debug("WAITED FOR FREE CONNECTION, GOT #{@free_connections[args].last}")
                            end
                        end
                        unless conn
                            while (!conn && !@free_connections[args].empty?)
                                conn = @free_connections[args].pop
                                unless connection_alive?(conn)
                                    remove_connection_nosync(conn, args)
                                    conn = nil
                                end
                            end
                        end
                    end
                    #Spider::Logger.debug("GOT CONNECTION #{args}")
                    
                }
                raise connect_exception if connect_exception
                raise StorageException, "Unable to get a connection" unless conn
                return conn
            end
            
            # Frees a connection, relasing it to the pool
            def release_connection(conn, conn_params)
                return unless conn
                @free_connections[conn_params] << conn
            end
            
            # Removes a connection from the pool.
            def remove_connection(conn, conn_params)
                @connection_semaphore.synchronize{
                    remove_connection_nosync(conn, conn_params)
                }
            end
            
            def remove_connection_nosync(conn, conn_params) #:nodoc:
                @free_connections[conn_params].delete(conn)
                @connections[conn_params].delete(conn)
            end
                
            # Checks whether a connection is still alive. Must be implemented by subclasses.
            def connection_alive?(conn)
                raise "Virtual"
            end
            
        end
        
        # The constructor takes the connection URL, which will be parsed into connection params.
        def initialize(url)
            super
        end
        
        # Instantiates a new connection with current connection params.
        def connect()
            @conn = self.class.get_connection(*@connection_params)
        end
        
        # True if currently connected.
        def connected?
            @conn != nil
        end
        
        # Returns the current connection, or creates a new one.
        # If a block is given, will disconnect after yielding.
        def connection
            is_connected = connected?
            connect unless is_connected
            if block_given?
                yield @conn
                disconnect unless is_connected
            end
            return @conn
        end
        
        # Releases the current connection to the pool.
        def disconnect
            # The subclass should check if the connection is alive, and if it is not call remove_connection instead
            begin
                self.class.release_connection(@conn, @connection_params)
            ensure
                @conn = nil
            end
            return nil
            #@conn = nil
        end
        
        # Returns the default mapper for the storage.
        # If the storage subclass contains a MapperExtension module, it will be mixed-in with the mapper.
        def get_mapper(model)
            mapper = Spider::Model::Mappers::DbMapper.new(model, self)
            if (self.class.const_defined?(:MapperExtension))
                mapper.extend(self.class.const_get(:MapperExtension))
            end
            return mapper
        end
        
        # True if given named capability is supported by the DB.
        def supports?(capability)
            self.class.capabilities[capability]
        end
        
        def supports_transactions?
            return self.class.capabilities[:transactions]
        end
        
        # May be implemented by subclasses.
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
                
        ##############################################################
        #   Methods used to generate a schema                        #
        ##############################################################
        
        # Fixes a string to be used as a table name.
        def table_name(name)
            return name.to_s.gsub(':', '_')
        end
        
        # Fixes a string to be used as a sequence name.
        def sequence_name(name)
            return name.to_s.gsub(':', '_')
        end
        
        # Fixes a string to be used as a column name.
        def column_name(name)
            name = name.to_s
            name += '_field' if (self.class.reserved_keywords.include?(name.downcase)) 
            return name
        end
        
        
        # Returns the db type corresponding to an element type.
        def column_type(type, attributes)
            case type.name
            when 'String'
                'TEXT'
            when 'Text'
                'LONGTEXT'
            when 'Fixnum'
                'INT'
            when 'Float'
                'REAL'
            when 'BigDecimal', 'Spider::DataTypes::Decimal'
                'DECIMAL'
            when 'Date', 'DateTime'
                'DATE'
            when 'Spider::DataTypes::Binary'
                'BLOB'
            when 'Spider::DataTypes::Bool'
                'INT'
            end
        end
        
        # Returns the attributes corresponding to element type and attributes
        def column_attributes(type, attributes)
            db_attributes = {}
            case type.name
            when 'String', 'Spider::DataTypes::Text'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
            when 'Float'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
                db_attributes[:precision] = attributes[:precision] if (attributes[:precision])
            when 'BigDecimal'
                db_attributes[:precision] = attributes[:precision] || 65
                db_attributes[:scale] = attributes[:scale] || 2
            when 'Spider::DataTypes::Binary'
                db_attributes[:length] = attributes[:length] if (attributes[:length])
            when 'Spider::DataTypes::Bool'
                db_attributes[:length] = 1
            end
            db_attributes[:autoincrement] = attributes[:autoincrement] if supports?(:autoincrement)
            return db_attributes
        end
        
        # Returns the SQL for a QueryFuncs::Function
        def function(func)
            fields = func.elements.map{ |func_el|
                if (func_el.is_a?(Spider::QueryFuncs::Function))
                    function(func_el)
                else
                    func.mapper_fields[func_el]
                end
            }.join(', ')
            case func.func_name
            when :length
                return "LENGTH(#{fields})"
            when :trim
                return "TRIM(#{fields})"
            end
            raise NotImplementedError, "#{self.class} does not support function #{type}"
        end
        
        ##################################################################
        #   Preparing values                                             #
        ##################################################################
        
        # Prepares a value for saving.
        def value_for_save(type, value, save_mode)
            return prepare_value(type, value)
        end
        
        # Prepares a value that will be used in a condition.
        def value_for_condition(type, value)
            return prepare_value(type, value)
        end
        
        # Converts a value loaded from the DB to return it to the mapper.
        def value_to_mapper(type, value)
            if (type.name == 'String' || type.name == 'Spider::DataTypes::Text')
                enc = @configuration['encoding']
                if (enc && enc.downcase != 'utf-8')
                    begin
                        value = Iconv.conv('utf-8//IGNORE', enc, value) if value
                    rescue Iconv::InvalidCharacter
                        value = ''
                    end
                end
            end
            return value
        end
        
        # Prepares a value that will be used on the DB.
        def prepare_value(type, value)
            case type.name
            when 'String', 'Spider::DataTypes::Text'
                enc = @configuration['encoding']
                if (enc && enc.downcase != 'utf-8')
                    begin
                        value = Iconv.conv(enc+'//IGNORE', 'utf-8', value.to_s)
                    rescue Iconv::InvalidCharacter
                        value = ''
                    end
                end
            when 'BigDecimal'
                value = value.to_f
            end
            return value
        end
        
        # Executes a select query (given in struct form).
        def query(query)
            @last_query = query
            case query[:query_type]
            when :select
                sql, bind_vars = sql_select(query)
                execute(sql, *bind_vars)
            when :count
                query[:keys] = ['COUNT(*) AS N']
                sql, bind_vars = sql_select(query)
                return execute(sql, *bind_vars)[0]['N'].to_i
            end
        end
        
        # Returns a two element array, containing the SQL for given select query, and the variables to bind.
        def sql_select(query)
            @last_query_type = :select
            bind_vars = query[:bind_vars] || []
            tables_sql, tables_values = sql_tables(query)
            sql = "SELECT #{sql_keys(query)} FROM #{tables_sql} "
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
        
        def total_rows
            @total_rows
        end
        
        # Returns the SQL for select keys.
        def sql_keys(query)
            query[:keys].join(',')
        end
        
        # Returns an array containing the 'FROM' part of an SQL query (including joins),
        # and the bound variables, if any.
        def sql_tables(query)
            values = []
            sql = query[:tables].map{ |table|
                str = table
                if (query[:joins] && query[:joins][table])
                    join_str, join_values = sql_tables_join(query, table)
                    str += " "+join_str
                    values += join_values
                end
                str
            }.join(', ')
            return [sql, values]
        end
        
        # Returns SQL and bound variables for joins.
        def sql_tables_join(query, table)
            str = ""
            values = []
            query[:joins][table].each_key do |to_table|
                join, join_values = sql_joins(query[:joins][table][to_table])
                str += " "+join
                values += join_values
                if (query[:joins][to_table])
                    query[:joins][to_table].delete(table) # avoid endless loop
                    sub_str, sub_values = sql_tables_join(query, to_table)
                    str += " "+sub_str
                    values += sub_values
                end
            end
            return str, values
        end
        
        # Returns SQL and bound variables for a condition.
        def sql_condition(query)
            condition = query[:condition]
            return ['', []] unless (condition && condition[:values])
            bind_vars = []
            mapped = condition[:values].map do |v|
                if (v.is_a? Hash) # subconditions
                    # FIXME: optimize removing recursion
                    sql, vals = sql_condition({:condition => v})
                    bind_vars += vals
                    !sql.empty? ? "(#{sql})" : nil
                elsif (v[2].is_a? Spider::QueryFuncs::Expression)
                    sql_condition_value(v[0], v[1], v[2].to_s, false)
                else
                    v[1] = 'between' if (v[2].is_a?(Range))
                    v[2].upcase! if (v[1].to_s.downcase == 'ilike')
                    if (v[1].to_s.downcase == 'between')
                        bind_vars << v[2].first
                        bind_vars << v[2].last
                    else
                        bind_vars << v[2] unless v[2].nil?
                    end
                    sql_condition_value(v[0], v[1], v[2])
                end
            end
            return mapped.select{ |p| p != nil}.join(' '+condition[:conj]+' '), bind_vars
        end
        
        # Returns the SQL for a condition comparison.
        def sql_condition_value(key, comp, value, bound_vars=true)
            if (comp.to_s.downcase == 'ilike')
                comp = 'like'
                key = "UPPER(#{key})"
            end
            if (value.nil?)
                comp = comp == '=' ? "IS" : "IS NOT"
                sql = "#{key} #{comp} NULL"
            else
                if (comp.to_s.downcase == 'between')
                    if (bound_vars)
                        val0, val1 = value
                    else
                        val0 = val1 = '?'
                    end
                    sql = "#{key} #{comp} #{val0} AND #{val1}"
                else
                    val = bound_vars ? '?' : value
                    sql = "#{key} #{comp} #{val}"
                end
            end
            return sql
        end
        
        # def sql_join(joins)
        #     sql = ""
        #     joins.each_key do |from_table|
        #         joins[from_table].each do |to_table, conditions|
        #             conditions.each do |from_key, to_key|
        #                 sql += " AND " unless sql.empty?
        #                 sql += "#{from_table}.#{from_key} = #{to_table}.#{to_key}"
        #             end
        #         end
        #     end
        #     return sql
        # end
        
        # Returns SQL and values for DB joins.
        def sql_joins(joins)
            types = {
                :inner => 'INNER', :outer => 'OUTER', :left => 'LEFT OUTER', :right => 'RIGHT OUTER'
            }
            values = []
            sql = joins.map{ |join|
                sql_on = join[:keys].map{ |from_f, to_f| "#{join[:from]}.#{from_f} = #{join[:to]}.#{to_f}"}.join(' AND ')
                if (join[:condition])
                    condition_sql, condition_values = sql_condition({:condition => join[:condition]})
                    sql_on += " and #{condition_sql}"
                    values += condition_values
                end
                j = "#{types[join[:type]]} JOIN #{join[:to]}"
                j += " #{join[:as]}" if join[:as]
                j += " ON (#{sql_on})"
                j
            }.join(" ")
            return [sql, values]
        end
        
        # Returns SQL for the ORDER part.
        def sql_order(query)
            return '' unless query[:order]
            return query[:order].map{|o| "#{o[0]} #{o[1]}"}.join(' ,')
        end
        
        # Returns the LIMIT and OFFSET SQL.
        def sql_limit(query)
            sql = ""
            sql += "LIMIT #{query[:limit]} " if query[:limit]
            sql += "OFFSET #{query[:offset]} " if query[:offset]
            return sql
        end
        
        # Returns SQL and values for an insert statement.
        def sql_insert(insert)
            @last_query_type = :insert
            sql = "INSERT INTO #{insert[:table]} (#{insert[:values].keys.join(', ')}) " +
                  "VALUES (#{insert[:values].values.map{'?'}.join(', ')})"
            return [sql, insert[:values].values]
        end
        
        # Returns SQL and values for an update statement.
        def sql_update(update)
            @last_query_type = :update
            values = []
            tables = update[:table]
            if (update[:joins] && update[:joins][update[:table]])
                join_str, join_values = sql_tables_join(update, update[:table])
                tables += " "+join_str
                values += join_values
            end
            values += update[:values].values.reject{ |v| v.is_a?(Spider::QueryFuncs::Expression) }
            sql = "UPDATE #{tables} SET "
            sql += sql_update_values(update)
            where, bind_vars = sql_condition(update)
            values += bind_vars
            sql += " WHERE #{where}"
            return [sql, values]
        end
        
        # Returns the COLUMN = val, ... part of an update statement.
        def sql_update_values(update)
            update[:values].map{ |k, v| 
                v.is_a?(Spider::QueryFuncs::Expression) ? "#{k} = #{v}" : "#{k} = ?"
            }.join(', ')
        end
        
        # Returns SQL and bound values for a DELETE statement.
        def sql_delete(delete, force=false)
            @last_query_type = :delete
            where, bind_vars = sql_condition(delete)
            where = "1=0" if !force && (!where || where.empty?)
            sql = "DELETE FROM #{delete[:table]}"
            sql += " WHERE #{where}" if where && !where.empty?
            return [sql, bind_vars]
        end
        
        # Returns an array of SQL statements for a create structured description.
        def sql_create_table(create)
            name = create[:table]
            fields = create[:fields]
            sql_fields = ''
            fields.each do |field|
                attributes = field[:attributes]
                attributes ||= {}
                length = attributes[:length]
                sql_fields += ', ' unless sql_fields.empty?
                sql_fields += sql_table_field(field[:name], field[:type], attributes)
            end
            if (create[:attributes][:primary_key])
                primary_key_fields = create[:attributes][:primary_key].join(', ')
                sql_fields += ", PRIMARY KEY (#{primary_key_fields})"
            end
            ["CREATE TABLE #{name} (#{sql_fields})"]
        end
        
        # Returns an array of SQL statements for an alter structured description.
        def sql_alter_table(alter)
            current = alter[:current]
            table_name = alter[:table]
            add_fields = alter[:add_fields]
            alter_fields = alter[:alter_fields]
            alter_attributes = alter[:attributes]
            sqls = []
            
            add_fields.each do |field|
                name, type, attributes = field
                sqls += sql_add_field(table_name, field[:name], field[:type], field[:attributes])
            end
            alter_fields.each do |field|
                name, type, attributes = field
                sqls += sql_alter_field(table_name, field[:name], field[:type], field[:attributes])
            end
            if (alter_attributes[:primary_key])
                sqls << "ALTER #{table_name} DROP PRIMARY KEY" if (current && current[:attributes][:primary_key])
                sqls << "ALTER TABLE #{table_name} ADD PRIMARY KEY "+alter_attributes[:primary_key].join(', ')
            end
            return sqls
        end
        
        # Executes a create table structured description.
        def create_table(create)
            sqls = sql_create_table(create)
            sqls.each do |sql|
                execute(sql)
            end
        end
        
        # Executes an alter table structured description.
        def alter_table(alter)
            sqls = sql_alter_table(alter)
            sqls.each do |sql|
                execute(sql)
            end
        end
        
        # Drops a field from the DB.
        def drop_field(table_name, field_name)
            sqls = sql_drop_field(table_name, field_name)
            sqls.each{ |sql| execute(sql) }
        end
        
        # Drops a table from the DB.
        def drop_table(table_name)
            sqls = sql_drop_table(table_name)
            sqls.each{ |sql| execute(sql) }
        end
        
        # Returns the SQL for a field definition (used in create and alter table)
        def sql_table_field(name, type, attributes)
            f = "#{name} #{type}"
            if (type == 'DECIMAL')
                f += "(#{attributes[:precision]}, #{attributes[:scale]})"
            else
                if attributes[:length] && attributes[:length] != 0
                    f += "(#{attributes[:length]})"
                elsif attributes[:precision]
                    f += "(#{attributes[:precision]}"
                    f += "#{attributes[:scale]}" if attributes[:scale]
                    f += ")"
                end
            end
            return f
        end
        
        # Returns an array of SQL statements to add a field.
        def sql_add_field(table_name, name, type, attributes)
            ["ALTER TABLE #{table_name} ADD #{sql_table_field(name, type, attributes)}"]
        end
        
        # Returns an array of SQL statements to alter a field.
        def sql_alter_field(table_name, name, type, attributes)
            ["ALTER TABLE #{table_name} MODIFY #{sql_table_field(name, type, attributes)}"]
        end
        
        # Returns an array of SQL statements to drop a field.
        def sql_drop_field(table_name, field_name)
            ["ALTER TABLE #{table_name} DROP COLUMN #{field_name}"]
        end
        
        # Returns an array of SQL statements needed to drop a table.
        def sql_drop_table(table_name)
            ["DROP TABLE #{table_name}"]
        end
        
        # Checks if a DB field is equal to a schema field.
        def schema_field_equal?(current, field)
            attributes = field[:attributes]
            return false unless current[:type] == field[:type] || 
                (self.class.type_synonyms && self.class.type_synonyms[current[:type]] && self.class.type_synonyms[current[:type]].include?(field[:type]))
            try_method = :"schema_field_#{field[:type].downcase}_equal?"
            return send(try_method, current, field) if (respond_to?(try_method))
            current[:length] ||= 0; attributes[:length] ||= 0; current[:precision] ||= 0; attributes[:precision] ||= 0
            return false unless current[:length] == attributes[:length]
            return false unless current[:precision] == attributes[:precision]
            return true
        end

        
        # Checks if the conversion from a current DB field to a schema field is safe, i.e. can 
        # be done without loss of data.
        def safe_schema_conversion?(current, field)
            attributes = field[:attributes]
            safe = self.class.safe_conversions
            if (current[:type] != field[:type])
                if safe[current[:type]] && safe[current[:type]].include?(field[:type])
                    return true 
                else
                    return false
                end
            end
            return true if ((!current[:length] || current[:length] == 0) \
                            || (attributes[:length] && current[:length] <= attributes[:length])) && \
                           ((!current[:precision] || current[:precision] == 0) \
                           || (attributes[:precision] && current[:precision] <= attributes[:precision]))
            return false
        end
        
        # Shortens a DB name up to length.
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
        
        # Returns an array of the table names currently in the DB.
        def list_tables
            raise "Unimplemented"
        end
        
        # Returns a description of the table as currently present in the DB.
        def describe_table(table)
            raise "Unimplemented"
        end
        
        # Post processes column information retrieved from current DB.
        def parse_db_column(col)
            col
        end
        
        ##############################################################
        #   Aggregates                                               #
        ##############################################################
        
        def sql_max(max)
            values = []
            from_sql, from_values = sql_tables(max)
            values += from_values
            sql = "SELECT MAX(#{max[:field]}) AS M FROM #{from_sql}"
            if (max[:condition])
                condition_sql, condition_values = sql_condition(max)
                sql += " WHERE #{condition_sql}"
                values += condition_values
            end
            return sql, values
        end
        
        ##############################################################
        #   Reflection                                               #
        ##############################################################
            
            
        def reflect_column(table, column_name, column_attributes)
            column_type = column_attributes[:type]
            el_type = nil
            el_attributes = {}
            case column_type
            when 'TEXT'
                el_type = String
            when 'LONGTEXT'
                el_type = Text
            when 'INT'
                if (column_attributes[:length] == 1)
                    el_type = Spider::DataTypes::Bool
                else
                    el_type = Fixnum
                end
            when 'REAL'
                el_type = Float
            when 'DECIMAL'
                el_type = BigDecimal
            when 'DATE'
                el_type = DateTime
            when 'BLOB'
                el_type = Spider::DataTypes::Binary
            end
            return el_type, el_attributes
            
        end
            
        
    end
    
end; end; end; end
