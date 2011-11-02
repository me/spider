require 'spiderfw/model/storage/db/db_storage'
require 'sqlite3'

module Spider; module Model; module Storage; module Db
    
    class SQLite < DbStorage
        @reserved_keywords = superclass.reserved_keywords + []
        @capabilities = {
            :autoincrement => true,
            :sequences => true,
            :transactions => true,
            :foreign_keys => false
        }

        class << self; attr_reader :reserved_kewords; end
        
        def self.max_connections
            1
        end
        
        def self.base_types
            super << Spider::DataTypes::Binary
        end
        
        def self.new_connection(file)
            db = SQLite3::Database.new(file)
            db.results_as_hash = true
            return db
        end
        
        def self.connection_alive?(conn)
            !conn.closed?
        end
        
        def release
            begin
                #curr[:conn].close
                super
            rescue
                curr[:conn] = nil
            end
        end
        
        
        def parse_url(url)
            if (url =~ /(.+?):\/\/(.+)/)
                @file = $2
                @file = Spider.paths[:root] + '/' + @file[2..-1] if (@file[0..1] == './')
            else
                raise ArgumentError, "SQLite url '#{url}' is invalid"
            end
            @connection_params = [@file]
        end
        
        def do_start_transaction
            return unless transactions_enabled?
            connection.transaction
        end
        
        def in_transaction?
            return false unless transactions_enabled?
            return curr[:conn] && curr[:conn].transaction_active?
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
                
        def assigned_key(key)
            curr[:last_insert_row_id]
        end
        
        def value_for_save(type, value, save_mode)
             case type.name
             when 'Spider::DataTypes::Binary'
                 return SQLite3::Blob.new(value)
             end
             return value
         end

         def execute(sql, *bind_vars)
             begin
                 if (bind_vars && bind_vars.length > 0)
                     debug_vars = bind_vars.map{|var| var = var.to_s; var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}.join(', ')
                 end
                 debug("sqlite executing:\n#{sql}\n[#{debug_vars}]")

                 result = connection.execute(sql, *bind_vars)
                 curr[:last_insert_row_id] = connection.last_insert_row_id
                 result.extend(StorageResult)
                 curr[:last_result] = result
                 if block_given?
                     result.each{ |row| yield row }
                 else
                     return result
                 end
             ensure
                 release unless in_transaction?
             end
         end
         

         def prepare(sql)
             debug("sqlite preparing: #{sql}")
             return connection.prepare(sql)
         end

         def execute_statement(stmt, *bind_vars)
             stmt.execute(bind_vars)
         end
         
         def total_rows
             return nil unless curr[:last_query]
             q = curr[:last_query]
             unless (q[:offset] || q[:limit])
                 return curr[:last_result_length] ? curr[:last_result_length] : nil
             end
             q[:offset] = q[:limit] = nil
             q[:keys] = ["COUNT(*) AS N"]
             res = execute(sql_select(q), q[:bind_vars])
             return res[0]['N']
         end
         
         #############################################################
         #   SQL methods                                             #
         #############################################################
         
         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################

         def list_tables
             return execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").flatten
         end

         def describe_table(table)
             columns = {}
             primary_keys = []
             res = execute("PRAGMA table_info('#{table}')")
             res.each do |row|
                 name = row['name']
                 type = row['type']
                 length = nil
                 precision = nil
                 if type =~ /(.+)\((.+)\)/
                     type = $1
                     length = $2
                 end
                 if length && length.include?(",")
                     length, precision = length.split(',')
                 end
                 length = length.to_i if length
                 precision = precision.to_i if length
                 primary_keys << name if row['pk'] == "1"
                 columns[name] = {:type => type, :length => length, :precision => precision}
             end
             # stmt.columns.each_index do |index|
             #     field = stmt.columns[index]
             #     columns[field] ||= {}
             #     if (stmt.types[index] =~ /([^\(]+)(?:\((\d+)\))?/)
             #         columns[field][:type] = $1
             #         columns[field][:length] = $2.to_i if $2
             #     end
             # end
             # stmt.close
             return {:columns => columns, :primary_keys => primary_keys}
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
    
    class SQLiteException < RuntimeError
    end
    
end; end; end; end