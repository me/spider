require 'spiderfw/controller/spider_controller'
require 'spiderfw/controller/formats/html'

module Spider
    
    class HTTPController < Controller
        
        
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
        
        def execute(action='', *arguments)
            @extensions = {
                'js' => {:content_type => 'application/javascript'},
                'html' => {:content_type => 'text/html', :mixin => HTML}
            }
            if (action =~ /\.(\w+)$/)
                @extension = $1
                if (ext = @extensions[$1])
                    (content_type = ext[:content_type]) && @response.headers['Content-Type'] = content_type
                    (mixin = ext[:mixin]) && extend(mixin)
                end
            end
            super
        end
        
        
        def dispatched_object(route)
            super
            
        end
        
        # def before(action, *params)
        #     begin
        #         super
        #     rescue NotFoundException
        #         @response.status = 404
        #     end
        # end
        
        def ensure(action='', *arguments)
            dispatch(:ensure, action, *arguments)
            $stdout = @previous_stdout
        end
        
        
        def get_route(path)
            path.slice!(0) if path.length > 0 && path[0].chr == "/"
            return Route.new(:path => path, :dest => Spider::SpiderController, :action => path)
        end
        
        def try_rescue(exc)
            if (exc.is_a?(NotFoundException))
                @response.status = 404
            else
                super
            end
        end
        
        
    end
    
end