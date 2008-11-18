module Spider
    
    class SpiderController < Controller
        
        def initialize(request, response, scene=nil)
            Spider.apps.each do |name, app|
                app_path = app.name.gsub('::', '/')
                route(Regexp.new("#{app_path}$", Regexp::IGNORECASE), :redirect_to_app)
                route(app_path+'/', app.controller_class, :ignore_case => true)
            end
            super
        end
        
        def redirect_to_app()
            @response.status = 301
            @response.headers["Location"] = @dispatched_action+'/'
        end
        
    end
    
    
end