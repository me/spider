module Spider
    
    class SpiderController < Controller
        
        def initialize(env, response, scene=nil)
            Spider.apps.each do |name, app|
                route(app.name.gsub('::', '/'), app.controller_class, :ignore_case => true)
            end
            super
        end
        
    end
    
    
end