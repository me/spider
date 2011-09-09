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
                d = @data
                if self.translate?
                    Spider::GetText.in_domain(self.app.short_name){
                        @data.each do |k, v|
                            d[k] = _(v)
                        end
                    }
                end
                d
            end
            
            def translate=(val)
                @translate = val
            end
            
            def translate?
                @translate
            end
            
            def mapper
                return Mappers::HashMapper.new(self, self.data)
            end
            
            def get_storage(url='default')
                self.data
            end
            
        end
        
        def mapper
            return self.class.mapper
        end
        
        def ==(val)
            return super unless self.class.primary_keys.length == 1
            pk = self.class.primary_keys.first
            if pk.type == String || pk.type == Symbol
                if val.is_a?(String) || val.is_a?(Symbol)
                    return val.to_s == self.get(pk).to_s
                end
            elsif val.is_a?(pk.type)
                return val == self.get(pk)
            end
            return super
            
        end
        
    end
    
    
end; end