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
                    storage = Db::SQLite.new(url)
                when 'oci8'
                    storage = Db::OCI8.new(url)
                when 'mysql'
                    storage = Db::Mysql.new(url)
                end
                if (connector)
                    case connector
                    when 'odbc'
                        storage.extend(Db::Connectors::ODBC)
                    end
                end
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