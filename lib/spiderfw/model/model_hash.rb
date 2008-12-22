module Spider; module Model
    
    class ModelHash < Hash
        
        def initialize(hash=nil)
            super()
            merge!(hash) if (hash && hash.is_a?(Hash))
        end
        
        def get_deep_obj
            return self.class.new
        end
        
        def []=(key, val)
            if (val.is_a?(BaseModel))
                n = self.class.new
                val.each_val do |el, v|
                    n[el] = v
                end
                val = n
            end
            key = key.name if key.class == Element
            parts = key.to_s.split('.', 2)
            return super(key.to_sym, val) unless parts[1]
            parts[0] = parts[0].to_sym
            self[parts[0]] = get_deep_obj unless self[parts[0]].is_a?(self.class)
            self[parts[0]][parts[1]] = val
        end
        
        def [](key)
            # TODO: deep
            key = key.name if key.class == Element
            super(key.to_sym)
        end
        
    end
    
end; end;