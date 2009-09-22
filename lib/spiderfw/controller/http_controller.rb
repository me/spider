require 'spiderfw/controller/spider_controller'
require 'spiderfw/controller/session/memory_session'
require 'spiderfw/controller/session/file_session'

module Spider
    
    class HTTPController < Controller
        include HTTPMixin
        
        
        def initialize(request, response, scene=nil)
            response.status = Spider::HTTP::OK
            response.headers = {
                'Content-Type' => 'text/plain',
                'Connection' => 'close'
            }
            @previous_stdout = $stdout
            Thread.current[:stdout] = response.server_output
            $out = ThreadOut
            $stdout = ThreadOut if Spider.conf.get('http.seize_stdout')
            request.extend(HTTPRequest)
            super(request, response, scene)
        end
        
        def before(action='', *arguments)
            if (@request.env['HTTP_TRANSFER_ENCODING'] == 'Chunked' && !@request.server.supports?(:chunked_request))
                raise HTTPStatus.NOT_IMPLEMENTED
            end
            @request.cookies = Spider::HTTP.parse_query(@request.env['HTTP_COOKIE'], ';')
            @request.session = Session.get(@request.cookies['sid'])
            @response.cookies['sid'] = @request.session.sid
            @response.cookies['sid'].path = '/'
            @request.params = {}
            if (@request.env['QUERY_STRING'])
                @request.params = Spider::HTTP.parse_query(@request.env['QUERY_STRING'])
            end
            if (@request.env['REQUEST_METHOD'] == 'POST' && @request.env['HTTP_CONTENT_TYPE'] && @request.env['HTTP_CONTENT_TYPE'].include?('application/x-www-form-urlencoded'))
                @request.params.merge!(Spider::HTTP.parse_query(@request.read_body))
            end
            if (@request.env['HTTP_ACCEPT_LANGUAGE'])
                lang = @request.env['HTTP_ACCEPT_LANGUAGE'].split(';')[0].split(',')[0]
                GetText.locale = lang
            end
            if (action =~ /(.+)\.(\w+)$/) # strip extension, set format
                action = $1
                @request.format = $2.to_sym
            end
            super(action, *arguments)
        end
        
        def execute(action='', *arguments)
            # FIXME: cache stripped action?
            action = $1 if (action =~ /(.+)\.(\w+)$/) # strip extension, set format
            super(action, *arguments)
        end
        
        def after(action='', *arguments)
            # FIXME: cache stripped action?
            action = $1 if (action =~ /(.+)\.(\w+)$/) # strip extension, set format
            @request.session.persist if @request.session
            super(action, *arguments)
        end
        
        def ensure(action='', *arguments)
            dispatch(:ensure, action, *arguments)
            $stdout = @previous_stdout
        end
        
        
        def get_route(path)
            path = path.clone
            path.slice!(0) if path.length > 0 && path[0].chr == "/"
            return Route.new(:path => path, :dest => Spider.home.controller, :action => path)
        end
        
        module HTTPRequest
            
            # Returns PATH_INFO reversing any proxy mappings if needed.
            def path
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping(self.env['PATH_INFO'])
            end
            
            def full_path
                'http://'+self.env['HTTP_HOST']+path
            end
            
            # Returns the REQUEST_URI reversing any proxy mappings if needed
            def uri
                Spider::ControllerMixins::HTTPMixin.reverse_proxy_mapping(self.env['REQUEST_URI'])
            end
            
            # Returns #uri prefixed with http:// and the HTTP_HOST
            def full_uri
                'http://'+self.env['HTTP_HOST']+uri
            end
            
        end
    
        
        
    end
    
end