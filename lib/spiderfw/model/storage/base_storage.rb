module Spider; module Model; module Storage
    
    class BaseStorage
        
        def initialize(url)
            parse_url(url)
        end
        
        def parse_url(url)
            raise StorageException, "Unimplemented"
        end
        
        def get_default_mapper(model)
            raise StorageException, "Unimplemented"
        end
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class StorageException < RuntimeError
    end
    
    
    
end; end; end