require 'spiderfw/model/storage/base_storage'
require 'spiderfw/model/mappers/document_mapper'

module Spider; module Model; module Storage; module Document
    
    class DocumentStorage < Storage::BaseStorage
        
        @capabilities = {
            :embedding => true,
            :transactions => false
        }
        
        def self.storage_type
            :document
        end
        
        # Returns the default mapper for the storage.
        # If the storage subclass contains a MapperExtension module, it will be mixed-in with the mapper.
        def get_mapper(model)
            mapper = Spider::Model::Mappers::DocumentMapper.new(model, self)
            if (self.class.const_defined?(:MapperExtension))
                mapper.extend(self.class.const_get(:MapperExtension))
            end
            return mapper
        end
        
        def generate_pk
            Spider::DataTypes::UUID.auto_value
        end
        
    end
    
    
end; end; end; end