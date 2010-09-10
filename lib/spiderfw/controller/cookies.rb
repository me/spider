require 'spiderfw/controller/cookie'

module Spider
    
    class Cookies < Hash
        
        def []=(key, val)
            super(key.to_s, Cookie.new(val))
        end
        
    end
    
    
end