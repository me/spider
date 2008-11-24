module Spider; module Model
    
    module Storage
        
        def self.get_storage(type, url)
            case type
            when 'db'
                adapter = url.match(/^(.+?):\/\//)[1]
                case adapter
                when 'sqlite'
                    storage = Db::SQLite.new(url)
                when 'oci8'
                    storage = Db::OCI8.new(url)
                end
            end
        end
        
        # Utility method
        
        # Increments a named sequence and returns the new value
        def next_sequence(name)
            dir = @model.name.sub('::Models', '').gsub('::', '/')
            FileUtils.mkpath('var/sequences/'+dir)
            path = 'var/sequences/'+dir+'/'+name
            seq = 0
            File.open(path, 'a+') do |f|
                f.rewind
                f.flock File::LOCK_EX
                seq = f.gets.to_i
                f.close
            end
            seq += 1
            File.open(path, 'w+') do |f|
                f.print(seq)
                f.flock File::LOCK_UN
                f.close
            end
            return seq
        end
        
        module StorageResult
            attr_accessor :total_rows
            
        end
        
        class StorageException < RuntimeError
        end
        
        ###############################
        #   Autoload                  #
        ###############################
        
        Storage.autoload(:Db, 'spiderfw/model/storage/db/db')
                
    end
    
end; end