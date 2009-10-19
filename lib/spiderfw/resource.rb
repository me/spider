module Spider
    
    class Resource
        attr_reader :path
        attr_reader :definer
        
        def initialize(path, definer=nil)
            @path = path
            @definer = definer
        end
        
        def to_s
            @path
        end
        
    end
    
end
