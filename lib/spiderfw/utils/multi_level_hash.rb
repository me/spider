module Spider
    
    # Utility that makes the including Hash accept a dotted syntax for keys.
    # The dotted syntax can be used to access and create on the fly sub-hashes. 
    # Example:
    #   h = MultiLevelHash.new
    #   h['one.two.three'] = 'some val'
    #   p h => {'one' => {'two' => {'three' => 'some val'}}}
    #   p h['one.two.three'] => 'some val'
    #   p h['four.five'] => nil
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
        
    # Hash including HashDottedAccess.
    class MultiLevelHash < Hash
        include HashDottedAccess
        
    end
    
    
end