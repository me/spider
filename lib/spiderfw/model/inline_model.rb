require 'spiderfw/model/mappers/hash_mapper'

module Spider; module Model
    
    # BaseModel having its data defined in the class.
    # The data must be an array of hashes, and will be handled by the Mappers::HashMapper.
    class InlineModel < BaseModel
        
        class <<self
            
            # Sets model data.
            def data=(val)
                @data = val
            end
            
            # Sets/gets model data.
            def data(val=nil)
                self.data = val if (val)
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