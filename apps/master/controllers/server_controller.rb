module Spider; module Master
    
    class ServerController < Spider::PageController
        
        __.html
        def index
            @scene.server = @request.misc[:server]
            render('server')
        end
        
        def resources
        end

    end
    
end; end