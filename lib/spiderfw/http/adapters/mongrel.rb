require 'mongrel'
require 'spiderfw/controller/http_controller'

module Spider; module HTTP
    
    class Mongrel < Server
        
        def start_server(opts={})
            opts = options(opts)
            @server = ::Mongrel::HttpServer.new(opts[:host], opts[:port])
            if (opts[:cgi]) 
                @server.register("/", MongrelCGIServlet.new(self))
            else 
                @server.register("/", MongrelServlet.new(self))
            end
            Spider.logger.info("Starting Mongrel on #{opts[:host]}:#{opts[:port]}")
            @server.run.join
        end
        
        
        def shutdown_server
            @server.stop
        end
        
        
    end
    
    class MongrelIO < ControllerIO
        
        def initialize(response, controller_response)
            @response = response
            @controller_response = controller_response
        end
        
        def write(msg)
            send_headers unless @response.header_sent
            @response.write(msg)
        end
        
        def send_headers
            @response.status = @controller_response.status
            @response.send_status(nil)
            @controller_response.headers.each do |key, val|
                @response.header[key] = val
            end
            @response.send_header
        end
        
        
        def flush
        end
        
    end
    
    
    class MongrelServlet < ::Mongrel::HttpHandler
        
        def initialize(server)
            @server = server
            #@request_notify = true
        end
        
        def request_begins(params)
            Spider.logger.debug( "REQUEST BEGINS:")
            Spider.logger.debug(params)
        end
        
        def request_progress(params, clen, total)
            Spider.logger.debug("REQUEST_PROGRESS")
            Spider.logger.debug(params)
            Spider.logger.debug(clen)
            Spider.logger.debug(total)
        end
        
        def process(request, response)
            @server.request_received
            server_vars = request.params.clone
            env = Spider::Environment.new
            env.request = normalize_request(request.params.clone)
            env.protocol = :http
            path = request.params['REQUEST_URI']

            controller_response = Spider::Response.new
            controller_response.body = MongrelIO.new(response, controller_response)

            begin
                controller = ::Spider::HTTPController.new(env, controller_response)
                controller.before(path)
                controller.execute(path)
                controller.after(path)                
            rescue => exc
                Spider.logger.error(exc)
                controller.ensure()
            ensure
                response.finished
                
            end
            
            
        end
        
        
        def normalize_request(params)
            return params
        end
        
    end
    
    class MongrelCGIServlet < ::Mongrel::HttpHandler
        
        def initialize(server)
            @server = server
        end
        
        def process(request, response)
            ENV['SPIDER_PATH'] = $SPIDER_PATH
            request.params.each do |key, val|
                ENV[key] = val
            end
            io = IO.popen("ruby "+$SPIDER_PATH+"/lib/spiderfw/http/adapters/cgi.rb")
            
            headers_sent = false
            while(io.gets)
                if !response.header_sent
                    if ($_ == "\n")
                        unless response.status_sent
                            response.status = 200
                            response.send_status(nil)
                        end
                        response.send_header 
                    else
                        parse_header($_, response)
                    end
                else
                    response.write($_)
                end
            end
            io.close
            response.finished
        
        end
        
        def parse_header(str, response)
            key, val = str.split(':', 2)
            return unless key
            key.strip!
            val.strip! if val
            if (val)
                if (key == 'Status')
                    response.status = val
                    response.send_status(nil)
                end
                response.header[key] = val
            elsif(str =~ /^(\d+)\s*/)
                response.status = $1
                response.send_status(nil)
            end 
        end
        
    end
    
end; end