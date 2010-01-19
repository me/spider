
module Spider; module Model
    
    module Storage
        
        
        def self.get_storage(type, url)
            case type
            when 'db'
                matches = url.match(/^(.+?):\/\/(.+)/)
                adapter = matches[1]
                rest = matches[2]
                if (adapter =~ /(.+):(.+)/)
                    connector = $1
                    adapter = $2
                    url = "#{adapter}://#{rest}"
                end
                case adapter
                when 'sqlite'
                    class_name = :SQLite
                when 'oci8'
                    class_name = :OCI8
                when 'mysql'
                    class_name = :Mysql
                when 'mssql'
                    class_name = :MSSQL
                end
                klass = Db.const_get(class_name)
                if (connector)
                    case connector
                    when 'odbc'
                        conn_mod = :ODBC
                    end
                    conn_class = "#{conn_mod}#{class_name}"
                    if Db.const_defined?(conn_class)
                        klass = Db.const_get(conn_class)
                    else
                        klass = Db.const_set(conn_class, Class.new(klass))
                        klass.instance_eval{ include Db::Connectors.const_get(conn_mod)}
                    end
                end
                storage = klass.new(url)
                return storage
            end
        end
        
        module StorageResult
            attr_accessor :total_rows
            
        end
        
        class StorageException < RuntimeError
        end
        
        class DuplicateKey < StorageException
        end
        
        ###############################
        #   Autoload                  #
        ###############################
        
        Storage.autoload(:Db, 'spiderfw/model/storage/db/db')
                
    end
    
end; end

require 'spiderfw/model/storage/db/db'
