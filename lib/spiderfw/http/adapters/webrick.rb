require 'webrick'
require 'stringio'

module Spider; module HTTP

    class WEBrick < Server

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

    class WEBrickServlet < ::WEBrick::HTTPServlet::AbstractServlet

        def service(request, response)
            server_vars = request.meta_vars.clone
            env = Spider::Environment.new
            env[:server] = server_vars
            env[:protocol] = 'http'
            env[:addr] = request.addr
            Spider.logger.debug("Env:")
            Spider.logger.debug(env)
            Spider.logger.debug("Request:")
            Spider.logger.debug(request)
            
            r, w = IO.pipe
            response.body = r
            
            controller_response = Spider::Response.new
            controller_response.body = w
            
            #path = server_vars['REQUEST_URI'].chomp('/')
            path = request.path.chomp('/')
            

            #$stdout = w
            
            begin
                controller = ::Spider::HTTPController.new(env, controller_response)
                controller.before(path)
            rescue => exc
                Spider.logger.error("Error during before:")
                Spider.logger.error(exc)
                controller.ensure()
                response.status = controller.response.status
                controller.response.headers.each do |key, val|
                    response[key] = val
                end
                $stdout = STDOUT
                w.close
                return
            end
            
            response.status = controller.response.status
            controller.response.headers.each do |key, val|
                response[key] = val
            end
            
           
            controllerThread = Thread.start do
                begin
                    controller.execute(path)
                    controller.after(path)
                rescue => exc
                    Spider.logger.debug("Error:")
                    Spider.logger.debug(exc)
                ensure
                    $stdout = STDOUT
                    w.close
                end
            end
        end
    end


end; end