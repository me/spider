require 'spiderfw/model/storage/base_storage'
require 'spiderfw/test/stubs/mapper_stub'

module Spider; module Test
    
    class StorageStub < Spider::Model::Storage::BaseStorage
        
        def get_mapper(model)
            mapper = Spider::Test::MapperStub.new(model, self)            
        end
        
        def parse_url(url)
        end
        
        def method_missing(method, *args)
        end
        
        def do_insert
        end
        
    end
    
end; end