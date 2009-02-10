require 'spiderfw/controller/spider_controller'
require 'spiderfw/controller/formats/html'
require 'spiderfw/controller/session/memory_session'
require 'spiderfw/controller/session/file_session'

module Spider
    
    class HTTPController < Controller
        
        
        def initialize(request, response, scene=nil)
            @response = response
            @response.status = 200
            @response.headers = {
                
                'Connection' => 'close'
            }
            @previous_stdout = $stdout
            Thread.current[:stdout] = response.body
            $stdout = ThreadOut
            request.user_id = request.cookies['user_id']
            request.session = Session.get(request.cookies['sid'])
            response.cookies['sid'] = request.session.sid
            response.cookies['sid'].path = '/'
            super
        end
        
        def before(action='', *arguments)
            @extensions = {
                'js' => {:format => :js, :content_type => 'application/javascript'},
                'html' => {:format => :html, :content_type => 'text/html', :mixin => HTML},
                #'json' => {:format => :json, :content_type => 'text/x-json'}
                'json' => {:format => :json, :content_type => 'text/plain'}
            }
            if (action =~ /(.+)\.(\w+)$/)
                @request.extension = $2
                if (ext = @extensions[$2])
                    @request.format = ext[:format]
                    (content_type = ext[:content_type]) && @response.headers['Content-Type'] = content_type
                    (mixin = ext[:mixin]) && extend(mixin)
                end
                @http_action_no_extension
                super($1, *arguments)
            else
                super
            end
        end
        
        def execute(action='', *arguments)
            if (@http_action_no_extension)
                super(@http_action_no_extension, *arguments)
            else
                super
            end
        end

        def after(action='', *arguments)
            debug("HTTP_CONTROLLER AFTER")
            request.session.persist
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