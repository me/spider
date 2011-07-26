module Spider
    class Controller
        
        class NotFound < RuntimeError
            attr_reader :path
            
            def initialize(path)
                @path = path
            end
            
            def to_s
                "NotFound: #{@path}"
            end
        end
        
        class BadRequest < RuntimeError
        end
        
        class Forbidden < RuntimeError
        end
        
        class ControllerError < RuntimeError
        end
        
        class Maintenance < RuntimeError
        end
        
    end
    
end