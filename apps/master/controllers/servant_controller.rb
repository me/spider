module Spider; module Master
    
    class ServantController < Spider::PageController
        
        __.html
        def index
            @scene.servant = @request.misc[:servant]
            render('servant')
        end
        
        def resources
        end

    end
    
end; end