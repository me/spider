module Spider; module Model
    
    class ModelHash < Hash
        
        def get_deep_obj
            return self.class.new
        end
        
        def []=(key, val)
            key = key.name if key.class == Element
            parts = key.to_s.split('.', 2)
            return super(key.to_sym, val) unless parts[1]
            parts[0] = parts[0].to_sym
            self[parts[0]] ||= get_deep_obj
            self[parts[0]][parts[1]] = val
        end
        
        def [](key)
            # TODO: deep
            key = key.name if key.class == Element
            super(key.to_sym)
        end
        
    end
    
end; end;