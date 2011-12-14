require 'mongrel'

module Spider; module HTTP
    
    class Mongrel < Server
        
        @supports = {
            :chunked_request => false
        }
        
        def start_server(opts={})
            opts = options(opts)
            @server = ::Mongrel::HttpServer.new(opts[:host], opts[:port])
            if (opts[:cgi]) 
                @server.register("/", MongrelCGIServlet.new(self))
            else 
                @server.register("/", MongrelServlet.new(self))
            end
            info_string = "Starting Mongrel on #{opts[:host]}:#{opts[:port]}"
            info_string += " (CGI mode)" if opts[:cgi]
            Spider.logger.info(info_string)
            @server.run.join
        end
        
        
        def shutdown_server
            @server.stop if @server
        end
        
        
    end
    
    class MongrelIO < ControllerIO
        
        def initialize(response, controller_response)
            @response = response
            @controller_response = controller_response
        end
        
        def write(msg)
            unless @response.header_sent
                #Spider::Logger.debug("Sending headers because wrote #{msg}")
                send_headers
            end
            @response.write(msg) rescue Errno::EPIPE # FIXME: is it bad?
        end
        
        def self.send_headers(controller_response, response)
            begin
                controller_response.prepare_headers
                response.status = controller_response.status
                response.send_status(nil)
                controller_response.headers.each do |key, val|
                    if (val.is_a?(Array))
                        val.each{ |v| response.header[key] = v }
                    else
                        response.header[key] = val
                    end
                end
                response.send_header
            rescue Errno::EPIPE, IOError
            end
        end
        
        def send_headers
            Spider::Logger.debug("---SENDING HEADERS----")
            
            self.class.send_headers(@controller_response, @response)

            
        end
        
        
        def flush
        end
        
    end
    
    
    class MongrelServlet < ::Mongrel::HttpHandler
        
        def initialize(server)
            @server = server
            if (Spider.conf.get('webserver.timeout'))
                begin
                  require 'system_timer'
                  @timer = SystemTimer
                rescue LoadError
                  require 'timeout'
                  @timer = Timeout
                end

            end
            
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
            Spider.request_started
            @server.request_received
            path = request.params['REQUEST_PATH']
            env = normalize_request(request.params.clone)
            controller_request = Spider::Request.new(env)
            controller_request.server = Mongrel
            controller_request.body = request.body
            controller_request.action = path
            controller_request.request_time = Time.now

            controller_response = Spider::Response.new
            if (Spider.conf.get('http.auto_headers'))
                controller_response.server_output = MongrelIO.new(response, controller_response)
            else
                controller_response.server_output = response
            end
            controller = nil
            begin
                main_block = lambda do
                    controller = ::Spider::HTTPController.new(controller_request, controller_response)
                    controller.extend(Spider::FirstResponder)
                    controller.call_before(path)
                    MongrelIO.send_headers(controller_response, response) unless Spider.conf.get('http.auto_headers')
                    controller.execute(path)
                    Spider::Logger.debug("Response:")
                    Spider::Logger.debug(controller.response)
                end
                if (Spider.conf.get('webserver.timeout'))
                    @timer.timeout(Spider.conf.get('webserver.timeout')) do
                        main_block.call
                    end
                else
                    main_block.call
                end
            rescue => exc
                Spider.logger.error(exc)
                controller.ensure if controller
                controller = nil
            ensure
                MongrelIO.send_headers(controller_response, response) unless response.header_sent
                Spider::Logger.debug("---- Closing Mongrel Response ---- ")
                unless response.socket.closed?
                    response.socket.flush
                    response.finished
                    response.socket.close
                end
                Spider.request_finished
            end
            if controller
                controller.call_after(path)
                controller.ensure
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
            ['SERVER_NAME', 'PATH_INFO', 'HTTP_ACCEPT_ENCODING', 'HTTP_USER_AGENT', 'SCRIPT_NAME',
             'SERVER_PROTOCOL', 'HTTP_COOKIE', 'HTTP_HOST', 'HTTP_ACCEPT_LANGUAGE', 'SERVER_SOFTWARE', 'REQUEST_PATH',
             'HTTP_VERSION', 'REQUEST_URI', 'SERVER_PORT', 'GATEWAY_INTERFACE', 'HTTP_ACCEPT', 'HTTP_CONNECTION',
             'REQUEST_METHOD', 'QUERY_STRING', 'CONTENT_TYPE', 'CONTENT_LENGTH'].each do |key|
                ENV[key] = request.params[key]
            end
            io = IO.popen("ruby "+$SPIDER_PATH+"/lib/spiderfw/http/adapters/cgi.rb", 'r+')
            
            while (request.body.gets)
                io.write($_)
            end
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
            Spider.logger.debug("HEADER #{str}")
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