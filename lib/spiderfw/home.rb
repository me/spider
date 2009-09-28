module Spider
    
    class Home
        attr_reader :path
        
        def initialize(path)
            @path = path
        end
        
        def controller
            require 'spiderfw/controller/home_controller'
            Spider::HomeController
        end
        
        def route_apps
            Spider.route_apps
        end
        
        def load_apps(*args)
            Spider.load_apps(*args)
        end
        
    end
    
    
end