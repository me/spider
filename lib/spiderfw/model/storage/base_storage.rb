module Spider; module Model; module Storage
    
    class BaseStorage
        include Spider::Logger
        attr_reader :url
        
        def self.base_types
            Model.base_types
        end
        
        def initialize(url)
            @url = url
            @configuration = {}
            parse_url(url)
        end
        
        def configure(conf)
            @configuration.merge!(conf)
        end
        
        def parse_url(url)
            raise StorageException, "Unimplemented"
        end
        
        def get_mapper(model)
            raise StorageException, "Unimplemented"
        end
        
        def prepare_value(type, value)
            return value
        end
        
        def ==(storage)
            return false unless self.class == storage.class
            return false unless self.url == storage.url
            return true
        end
        
        # Utility methods
        
        def sequence_file_path(name)
            path = 'var/sequences/'+name
            return path
        end
        
        def sequence_exists?(name)
            File.exist?(sequence_file_path(name))
        end
        
        def create_sequence(name, start=1, increment=1)
            sequence_next(name, start-1, increment)
        end
            
        
        def update_sequence(name, val)
            # not an alias because the set value behaviour of next_sequence isn't expected in subclasses
            sequence_next(name, val)
        end
        
        # Increments a named sequence and returns the new value
        def sequence_next(name, newval=nil, increment=1)
            path = sequence_file_path(name)
            FileUtils.mkpath(File.dirname(path))
            if newval
                seq = newval
            else
                seq = 0
                File.open(path, 'a+') do |f|
                    f.rewind
                    f.flock File::LOCK_EX
                    cur = f.gets
                    if (cur)
                        seq, increment_str = cur.split('|')
                    else
                        seq, increment_str = 0, 1
                    end
                    seq = seq.to_i
                    increment = increment_str.to_i if increment_str
                    f.close
                end
                seq += increment
            end
            File.open(path, 'w+') do |f|
                f.print(seq)
                f.print("|#{increment}") if (increment != 1)
                f.flock File::LOCK_UN
                f.close
            end
            return seq
        end
            
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class StorageException < RuntimeError
    end
    
    
    
end; end; end