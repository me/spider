module Spider
    
    class HomeController < Controller
        route 'spider/public', Spider.controller, :prepend => 'public/'
#        route 'spider', Spider.controller
                
        def self.route_app(app)
            #app_path = app.name.gsub('::', '/')
            app_path = app.route_url
            Spider::Logger.debug("ROUTING #{app_path} TO #{app.controller}")
            route(app_path, app.controller, :ignore_case => true)
        end
        
                        
    end
    
    
end