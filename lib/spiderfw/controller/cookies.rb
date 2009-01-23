require 'spiderfw/controller/cookie'

module Spider
    
    class Cookies < Hash
        
        def []=(key, val)
            Spider::Logger.debug("*********************************")
            Spider::Logger.debug("Creating cookie #{key}, #{val}")
            super(key.to_s, Cookie.new(val))
            Spider::Logger.debug(self)
        end
        
    end
    
    
end