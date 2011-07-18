module Spider; module Servant
    
    
    class ServantController < Spider::Controller
        
        def command
        end
        
        __.action
        def broken
            a = 0
            a / 0
        end
        
    end
    
    
end; end