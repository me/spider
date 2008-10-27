require 'spider/model/storage/db/db_storage'
require 'rubygems'
require 'sqlite3'

module Spider; module Model; module Storage; module Db
    
    class SQLite < DbStorage
        @reserved_keywords = superclass.reserved_keywords + []
        class << self; attr_reader :reserved_kewords; end
        
        def parse_url(url)
            if (url =~ /(.+?):\/\/(.+)/)
                @file = $2
            else
                raise SQLiteException, "SQLite url '#{url}' is invalid"
            end
        end
        
         def connect()
            $logger.debug "sqlite opening file #{@file}"
            @db = SQLite3::Database.new(@file)
            @db.results_as_hash = true
        end
        
        def connected?
            @db != nil
        end
        
        def disconnect
            @db.close
            @db = nil
        end
        
        def prepare_value(type, value)
             case type
             when 'binary'
                 return SQLite3::Blob.new(value)
             end
             return value
         end


         def execute(sql, *bind_vars)
             connect unless connected?
             $logger.debug("sqlite executing:\n#{sql}")
             if (bind_vars && bind_vars.length > 0)
                 debug_vars = bind_vars.map{|var| var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}.join(', ')
                 $logger.debug("bind vars:\n[#{debug_vars}]") 
             end
             result = @db.execute(sql, *bind_vars)
             if block_given?
                 result.each{ |row| yield row }
                 disconnect
             else
                 disconnect
                 return result
             end
         end

         def prepare(sql)
             $logger.debug("sqlite preparing: #{sql}")
             connect unless connected?
             return @db.prepare(sql)
         end

         def execute_statement(stmt, *bind_vars)
             stmt.execute(bind_vars)
         end
         
         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################

         def list_tables
             return execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").flatten
         end

         def describe_table(table)
             columns = {}
             stmt = prepare("select * from #{table}")
             stmt.columns.each_index do |index|
                 field = stmt.columns[index]
                 columns[field] ||= {}
                 if (stmt.types[index] =~ /([^\(]+)(?:\((\d+)\))?/)
                     columns[field][:type] = $1
                     columns[field][:length] = $2.to_i if $2
                 end
             end
             stmt.close
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
    
    class SQLiteException < RuntimeError
    end
    
end; end; end; end