require 'oci8'

module Spider; module Model; module Storage; module Db; module Connectors

    module OCI8
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        module ClassMethods
            
            def new_connection(user, pass, dbname, role)
                conn ||= ::OCI8.new(user, pass, dbname, role)
                conn.autocommit = true
                conn.non_blocking = true
                return conn
            end

            def disconnect(conn)
                conn.logoff
            end

            def connection_alive?(conn)
                begin
                    conn.autocommit?
                    return true
                rescue
                    return false
                end
            end
            
        end
        
        def release
            begin
                curr[:conn].autocommit = true if curr[:conn]
                super
            rescue
                self.class.remove_connection(curr[:conn], @connection_params)
                curr[:conn] = nil
            end
        end
        
        def do_start_transaction
            return unless transactions_enabled?
            connection.autocommit = false
        end
        
        def in_transaction?
            return false unless transactions_enabled?
            return curr[:conn] && !curr[:conn].autocommit?
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
        
        def prepare_value(type, value)
            value = super
            if (type < Spider::Model::BaseModel)
                type = type.primary_keys[0].type
            end
            return Oracle::OracleNilValue.new(Spider::Model.ruby_type(type)) if (value == nil)
            case type.name
            when 'Spider::DataTypes::Binary'
                return OCI8::BLOB.new(curr[:conn], value)
            end
            return value
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
                query_start
                cursor = connection.parse(sql)
                return cursor if (!cursor || cursor.is_a?(Fixnum))
                bind_vars.each_index do |i|
                    var = bind_vars[i]
                    if (var.is_a?(Oracle::OracleNilValue))
                        cursor.bind_param(i+1, nil, var.type, 0)
                    else
                        cursor.bind_param(i+1, var)
                    end
                end
                res = cursor.exec
                have_result = (cursor.type == ::OCI8::STMT_SELECT)
                # @cursor = connection.exec(sql, *bind_vars)
                if (have_result)
                    result = []
                    while (h = cursor.fetch_hash)
                        h.each do |key, val|
                            if val.respond_to?(:read)
                                h[key] = val.read
                            end
                        end
                        if block_given?
                            yield h
                        else
                            result << h
                        end
                    end
                end
                if (have_result)
                    unless block_given?
                        result.extend(StorageResult)
                        curr[:last_result] = result
                        return result
                    end
                else
                    return res
                end
                cursor.close

            rescue => exc
                curr[:conn].break if curr[:conn]
                rollback! if in_transaction?
                #curr[:conn].logoff
                release
                if (exc.message =~ /ORA-00001/)
                    raise Spider::Model::Storage::DuplicateKey
                else
                    raise exc
                end
            ensure
                query_finished
                cursor.close if cursor
                release if curr[:conn] && !in_transaction?
                post_execute
            end
        end
        

        def prepare(sql)
            debug("oci8 preparing: #{sql}")
            return connection.parse(sql)
        end

        def execute_statement(stmt, *bind_vars)
            stmt.exec(bind_vars)
        end
        
        
        def table_exists?(table)
            begin
                connection do |c|
                    c.describe_table(table)
                end
                Spider.logger.debug("TABLE EXISTS #{table}")
                return true
            rescue OCIError
                return false
            end
        end
        
        def do_describe_table(conn, table)
            columns = {}
            t = conn.describe_table(table)
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
            columns
        end
        
        
    end
    
    
end; end; end; end; end