module Spider
    
    class MultiLevelHash < Hash
        
        def []=(key, val)
            parts = key.to_s.split('.', 2)
            return super(key, val) unless parts[1]
            parts[0] = parts[0].to_sym
            self[parts[0]] ||= self.class.new
            self[parts[0]][parts[1]] = val
        end
        
        def [](key)
            parts = key.to_s.split('.', 2)
            return super(key) unless parts[1]
            parts[0] = parts[0].to_sym
            return self[parts[0]][parts[1]]
        end
        
        
    end
    
    
end