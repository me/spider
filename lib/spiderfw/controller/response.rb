module Spider
    
    class Response
        attr_accessor :status, :headers, :body
        
        def initialize
            @headers = {}
        end
        
        def register(key, val)
            instance_variable_set("@#{key}", val)
            self.class.send(:attr_accessor, key) # FIXME: threadsafety
        end
        
    end
    
    
end