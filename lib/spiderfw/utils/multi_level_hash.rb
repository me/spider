module Spider
    
    module HashDottedAccess
        def []=(key, val)
            parts = key.to_s.split('.', 2)
            return super(key, val) unless parts[1]
            self[parts[0]] ||= self.class.new
            self[parts[0]][parts[1]] = val
        end
        
        def [](key)
            parts = key.to_s.split('.', 2)
            return super(key) unless parts[1]
            return self[parts[0]][parts[1]]
        end
    end
        
    
    class MultiLevelHash < Hash
        include HashDottedAccess
        
    end
    
    
end