module Spider
    
    class Layout < Template
        allow_blocks :HTML, :Text, :Render, :Yield
        
        def render_and_yield(controller, action, arguments)
            Spider::Logger.debug("RENDER AND YIELD:")
            Spider::Logger.debug(controller)
            Spider::Logger.debug(action)
            Spider::Logger.debug(arguments)
            @scene[:yield_to] = {
                :controller => controller,
                :action => action,
                :arguments => arguments
            }
            render(@scene)
        end
        
        
    end
    
end