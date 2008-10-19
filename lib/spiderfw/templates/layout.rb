module Spider
    
    class Layout < Template
        allow_blocks :HTML, :Text, :Render, :Yield
        
        def render_and_yield(controller, action, arguments)
            @scene[:yield_to] = {
                :controller => controller,
                :action => action,
                :arguments => arguments
            }
            render(@scene)
        end
        
        
    end
    
end