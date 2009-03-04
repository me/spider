module Spider
    
    class SpiderController < Controller
        
        def self.route_app(app)
            Spider::Logger.debug("ROUTING APP #{app.name}")
            app_path = app.name.gsub('::', '/')
            route(app_path, app.controller, :ignore_case => true)
        end        
                
    end
    
    
end