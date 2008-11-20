module Spider; module Model; module Storage
    
    class BaseStorage
        include Spider::Logger
        attr_reader :url
        
        def initialize(url)
            @url = url
            parse_url(url)
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
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class StorageException < RuntimeError
    end
    
    
    
end; end; end