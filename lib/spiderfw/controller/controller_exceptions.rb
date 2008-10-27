module Spider
    class Controller
        
        class NotFoundException < RuntimeError
            attr_reader :path
            
            def initialize(path)
                @path = path
            end
            
            def to_s
                "NotFoundException: #{@path}"
            end
        end
        
    end
    
end