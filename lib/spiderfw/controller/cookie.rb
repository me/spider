module Spider
    
    class Cookie
        attr_accessor :val, :expires, :path, :domain, :secure
        
        def initialize(val)
            @val = val
            @expires = nil
            @path = nil
            @domain = nil
            @secure = nil
        end
        
        def to_s
            val
        end
        
    end
    
end