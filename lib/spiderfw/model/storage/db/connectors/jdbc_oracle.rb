require 'spiderfw/model/storage/db/connectors/jdbc'

module Spider; module Model; module Storage; module Db; module Connectors

    module JDBCOracle
        include Connectors::JDBC
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        RUBY_CLASS_TO_SQL_TYPE = {
          Fixnum => java.sql.Types::INTEGER,
          Bignum => java.sql.Types::INTEGER,
          Integer => java.sql.Types::INTEGER,
          Float => java.sql.Types::FLOAT,
          BigDecimal => java.sql.Types::NUMERIC,
          String => java.sql.Types::VARCHAR,
          Java::OracleSql::CLOB => Java::oracle.jdbc.OracleTypes::CLOB,
          Java::OracleSql::BLOB => Java::oracle.jdbc.OracleTypes::BLOB,
          Date => java.sql.Types::DATE,
          Time => java.sql.Types::TIMESTAMP,
          DateTime => java.sql.Types::DATE,
          Java::OracleSql::ARRAY => Java::oracle.jdbc.OracleTypes::ARRAY,
          Array => Java::oracle.jdbc.OracleTypes::ARRAY,
          Java::OracleSql::STRUCT => Java::oracle.jdbc.OracleTypes::STRUCT,
          Hash => Java::oracle.jdbc.OracleTypes::STRUCT,
          java.sql.ResultSet => Java::oracle.jdbc.OracleTypes::CURSOR,
        }
        
        module ClassMethods
        
            def new_connection(user, pass, dbname, role)
                driver = Connectors::JDBC.driver_class('oracle.jdbc.driver.OracleDriver')
                host = nil; port = nil; sid = nil
                if dbname =~ /(.+)(?::(\d+))?\/(.+)/
                    host = $1
                    port = $2
                    sid = $3
                else
                    raise ArgumentError, "Oracle db name must be in the host:port/SID form"
                end
                port ||= 1521
                url = "jdbc:oracle:thin:@#{host}:#{port}:#{sid}"
                conn = begin
                    Jdbc::DriverManager.getConnection(url, user, pass)
                rescue => exc
                    # bypass DriverManager to get around problem with dynamically loaded jdbc drivers
                    props = java.util.Properties.new
                    props.setProperty("user", user)
                    props.setProperty("password", pass)
                    driver.new.connect(url, props)
                end
                conn.setAutoCommit(true)
                return conn
            end
        
            def connection_alive?(conn)
                conn.pingDatabase()
            end
            
        end
        
        def release
            begin
                curr[:conn].setAutoCommit(true) if curr[:conn]
                super
            rescue
                self.class.remove_connection(curr[:conn], @connection_params)
                curr[:conn] = nil
            end
        end
        
        def do_start_transaction
            return unless transactions_enabled?
            connection.setAutoCommit(false)
        end
        
        def in_transaction?
            return false unless transactions_enabled?
            return curr[:conn] && !curr[:conn].getAutoCommit()
        end
        
        def do_commit
            return release unless transactions_enabled?
            curr[:conn].commit if curr[:conn]
            release
        end
        
        def do_rollback
            return release unless transactions_enabled?
            curr[:conn].rollback
            release
        end
        
        def value_to_mapper(type, value)
            return value if value.nil?
            case type.name
            when 'Time', 'Date', 'DateTime'
                return nil unless value
                d = value.dateValue
                t = value.timeValue
                value = Time.local(d.year + 1900, d.month + 1, d.date, t.hours, t.minutes, t.seconds)
                return value.to_datetime if type == DateTime
                return value.to_date
            when 'Spider::DataTypes::Text'
                if value.isEmptyLob
                    value = nil
                else
                    value = value.getSubString(1, value.length)
                end
            when 'Spider::DataTypes::Binary'
                if value.isEmptyLob
                    nil
                else
                    String.from_java_bytes(value.getBytes(1, value.length))
                end
            when 'Spider::DataTypes::Decimal', 'BigDecimal'
                value = value.to_s
            end
            return super(type, value)
        end
        
        def prepare_value(type, value)
            return Oracle::OracleNilValue.new(Spider::Model.ruby_type(type)) if (value == nil)
            case type.name
            when 'Spider::DataTypes::Decimal', 'BigDecimal'
                java_bigdecimal(value)
            when 'Date', 'DateTime'
                java_date(value)
            when 'Time'
                java_timestamp(value)
            when 'Spider::DataTypes::Text'
                if value
                    clob = Java::OracleSql::CLOB.createTemporary(connection, false, Java::OracleSql::CLOB::DURATION_SESSION)
                    clob.setString(1, value)
                    clob
                else
                    Java::OracleSql::CLOB.getEmptyCLOB
                end
            when 'Spider::DataTypes::Binary'
                if value
                    blob = Java::OracleSql::BLOB.createTemporary(connection, false, Java::OracleSql::BLOB::DURATION_SESSION)
                    blob.setBytes(1, value.to_java_bytes)
                    blob
                else
                    Java::OracleSql::BLOB.getEmptyBLOB
                end
            else
                super(type, value)
            end
        end
        
        
        def set_bind_variable(stmt, i, val)
            method = nil
            if val.is_a?(Oracle::OracleNilValue)
                type = RUBY_CLASS_TO_SQL_TYPE[val.type] || java.sql.Types::VARCHAR
                return stmt.setNull(i, type)
            else
                method = case val.class.name
                when 'Fixnum', 'Float'
                    :setInt
                when 'Java::JavaMath::BigDecimal'
                    :setBigDecimal
                when 'String'
                    :setString
                when 'Java::OracleSql::CLOB'
                    :setClob
                when 'Java::OracleSql::BLOB'
                    :setBlob
                when 'Java::OracleSql::DATE'
                    :setDATE
                when 'Java::OracleSql::Timestamp'
                    :setTimestamp
                end
            end
            raise "Can't find how to bind variable #{val}" unless method
            stmt.send(method, i, val)
        end
        
        def value_from_resultset(res, i, type)
            method = case type
            when :INTEGER, :SMALLINT, :TINYING, :BIGINTEGER, :NUMBER, :NUMERIC
                :getInt
            when :LONG
                :getLong
            when :FLOAT, :REAL
                :getFloat
            when :DECIMAL
                :getBigDecimal
            when :VARCHAR, :VARCHAR2, :LONGVARCHAR, :NCHAR, :CHAR
                :getString
            when :CLOB
                :getClob
            when :DATE, :TIME
                :getDATE
            when :TIMESTAMP
                :getTimestamp
            else
                raise "Don't know how to convert Oracle value of type #{type}"
            end
            res.send(method, i)
        end
        
        
        def execute(sql, *bind_vars)
            begin
                if (bind_vars && bind_vars.length > 0)
                    debug_vars = bind_vars.map{|var| var = var.to_s; var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}
                end
                curr[:last_executed] = [sql, bind_vars]
                if (Spider.conf.get('storage.db.replace_debug_vars'))
                    debug("oci8 #{connection} executing: "+sql.gsub(/:(\d+)/){
                        i = $1.to_i
                        v = bind_vars[i-1]
                        dv = debug_vars[i-1]
                        v.is_a?(String) ? "'#{dv}'" : dv
                    })
                else
                    debug_vars_str = debug_vars ? debug_vars.join(', ') : ''
                    debug("oci8 #{connection} executing:\n#{sql}\n[#{debug_vars_str}]")
                end
                query = curr[:last_query]
                stmt = connection.prepareStatement(sql)
                return unless stmt
                bind_vars.each_index do |i|
                    set_bind_variable(stmt, i+1, bind_vars[i])
                end
                res = nil
                if stmt.execute() # false means this is an update query
                    res = stmt.getResultSet()
                end
                if (res)
                    result = []
                    metadata = res.getMetaData
                    column_count = metadata.getColumnCount
                    column_names = []
                    column_types = []
                    1.upto(column_count) do |i|
                        column_names[i] = metadata.getColumnName(i)
                        column_types[i] = metadata.getColumnTypeName(i).to_sym
                    end
                    
                    while res.next()
                        h = {}
                        1.upto(column_count) do |i|
                            h[column_names[i]] = value_from_resultset(res, i, column_types[i])
                        end
                        if block_given?
                            yield h
                        else
                            result << h
                        end
                    end
                    res.close
                end
                if (res)
                    unless block_given?
                        curr[:last_result_length] = result.length
                        result.extend(StorageResult)
                        return result
                    end
                else
                    return res
                end
                stmt.close
            rescue => exc
                stmt.cancel if stmt
                # curr[:conn].break if curr[:conn]
                rollback! if in_transaction?
                #curr[:conn].logoff
                release
                raise
            ensure
                stmt.close if stmt
                release if curr[:conn] && !in_transaction?
            end
        end
        

        def prepare(sql)
            debug("oci8 preparing: #{sql}")
            return connection.prepareStatement(sql)
        end

        def execute_statement(stmt, *bind_vars)
            bind_vars.each_index do |i|
                set_bind_variable(stmt, i+1, bind_vars[i])
            end
            stmt.execute()
        end
        

        def table_exists?(table)
            connection do |c|
                res = get_table_metadata(c, table)
                while res.next()
                    return true
                end
                return false
            end
        end

        def do_describe_table(conn, table)
            md = get_db_metadata(conn)
            res = md.getColumns(nil, @user.upcase, table, nil)
            columns = []
            while res.next()
                col_name = res.getString("COLUMN_NAME")
                col = {
                    :name => col_name,
                    :type => res.getString("TYPE_NAME"),
                    :length => res.getInt("COLUMN_SIZE"),
                    :precision => res.getInt("DECIMAL_DIGITS"),
                }
                col.delete(:length) if (col[:precision])
                columns << col
            end
            columns
        end

        
        def get_db_metadata(conn)
            @db_metadata ||= conn.getMetaData()
        end
        
        def get_table_metadata(conn, table)
            get_db_metadata(conn).getTables(nil, @user.upcase, table, nil)
        end

        def java_date(value)
            value && Java::oracle.sql.DATE.new(value.strftime("%Y-%m-%d %H:%M:%S"))
        end

        def java_timestamp(value)
            value && Java::java.sql.Timestamp.new(value.year-1900, value.month-1, value.day, value.hour, value.min, value.sec, value.usec * 1000)
        end

        def java_bigdecimal(value)
            value && java.math.BigDecimal.new(value.to_s)
        end

        
    end
    
    
end; end; end; end; end