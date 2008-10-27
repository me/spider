require 'spiderfw/controller/spider_controller'
require 'spiderfw/controller/formats/html'

module Spider
    
    class HTTPController < Controller
        include HTML
        
        def initialize(env, response, scene=nil)
            @response = response
            @response.status = 200
            @response.headers = {
                'Content-Type' => 'text/plain',
                'Connection' => 'close'
            }
            @previous_stdout = $stdout
            $stdout = response.body
            super
        end
        
        def before(action, *params)
            begin
                super
            rescue NotFoundException
                @response.status = 404
            end
        end
        
        def ensure(action='', *arguments)
            dispatch(:ensure, action, *arguments)
            $stdout = @previous_stdout
        end
        
        
        def get_route(path)
            path.slice!(0) if path.length > 0 && path[0].chr == "/"
            return Route.new(:path => path, :dest => Spider::SpiderController, :action => path)
        end
        
        
    end
    
end