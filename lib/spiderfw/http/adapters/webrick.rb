require 'webrick'
require 'stringio'

module Spider; module HTTP

    class WEBrick < Server

        @supports = {
            :chunked_request => true
        }

        def options(opts)
            opts = super(opts)
            defaults = {
                :host   => 'localhost',
                :app    => 'spider'
            }
            return defaults.merge(opts)
        end


        def start_server(opts={})
            opts = options(opts)
            options = {
                :Port           => opts[:port],
                :BindAddress    => opts[:host]
            }
            @server = ::WEBrick::HTTPServer.new(options)
            @server.mount("/", WEBrickServlet)
            @server.start
        end

        def shutdown_server
            @server.shutdown
        end


    end
    
    class WEBrickRequest < Spider::Request
        attr_accessor :webrick_request
        
        
        def body(&proc)
            @webrick_request.body{ |buf| yield buf }
        end
        
        
    end
    
    class WEBrickIO < ControllerIO

        def initialize(response, controller_response, w)
            @response = response
            @controller_response = controller_response
            @w = w
            @headers_sent = false
            @webrick_thread = Thread.current
        end

        def write(msg)
            send_headers unless @headers_sent
            @w.write(msg)
        end

        def send_headers
            Spider::Logger.debug("---SENDING HEADERS----")
            @controller_response.prepare_headers
            @response.status = @controller_response.status
            @controller_response.headers.each do |key, val|
                if (val.is_a?(Array))
                    val.each{ |v| @response[key] = v }
                else
                    @response[key] = val
                end
            end
            @headers_sent = true
            @webrick_thread.run
        end

        def headers_sent?
            @headers_sent
        end
        
        def set_body_io(io)
            return super if headers_sent?
            @response.body = io
            send_headers
        end


        def flush
        end

    end


    class WEBrickServlet < ::WEBrick::HTTPServlet::AbstractServlet

        def service(request, response)
            env = prepare_env(request)
            controller_request = WEBrickRequest.new(env)
            controller_request.server = WEBrick
            controller_request.webrick_request = request
            path = request.path.chomp('/')
            controller_request.action = path

            r, w = IO.pipe
            response.body = r

            controller_response = Spider::Response.new
            controller_response.server_output = WEBrickIO.new(response, controller_response, w)


            controller_done = false

            controllerThread = Thread.start do
                begin
                    controller = ::Spider::HTTPController.new(controller_request, controller_response)
                    controller.extend(Spider::FirstResponder)
                    controller.before(path)
                    controller.execute(path)
                    controller.after(path)
                    Spider::Logger.debug("Controller done")
                rescue => exc
                    Spider.logger.debug("Error:")
                    Spider.logger.debug(exc)
                    controller.ensure() if controller
                ensure
                    controller_response.server_output.send_headers unless controller_response.server_output.headers_sent?
                    w.close
                    controller_done = true
                end
            end

            while (!controller_done && !controller_response.server_output.headers_sent?)
                Thread.stop
            end
            Spider.logger.debug("Webrick responding")
        end

        def prepare_env(request)
            # Spider.logger.debug("WEBRICK REQUEST: #{request}")
            # Spider.logger.debug("METAVARS: #{request.meta_vars}")
            return request.meta_vars.clone
        end

    end


end; end