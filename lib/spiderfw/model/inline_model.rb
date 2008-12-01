require 'spiderfw/model/mappers/hash_mapper'

module Spider; module Model
    
    class InlineModel < BaseModel
        
        class <<self
            
            def data=(val)
                @data = val
            end
            
            def data
                @data
            end
            
            def mapper
                return Mappers::HashMapper.new(self, self.data)
            end 
            
        end
        
        def mapper
            return self.class.mapper
        end
        
        
        
    end
    
    
end; end