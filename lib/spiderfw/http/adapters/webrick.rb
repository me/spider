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
            env = request.meta_vars.clone
            path = request.path.chomp('/')
            controller = ::Spider.controller.new
            
            r, w = IO.pipe

            # response.status = controller.status
            #             controller.headers.each do |key, val|
            #                 response[key] = val
            #             end
            response.body = r
            
            w.instance_eval { alias :_old_write :write }
            w.instance_variable_set(:@controller, controller)
            w.instance_variable_set(:@response, response)
            #w.instance_variable_set(:@server_thread, Thread.current)
            
            def w.write(s)
                $stderr << "Writing #{s}"
                self.instance_eval do
                    alias :write :_old_write
                end
                @controller.headers.each do |key, val|
                    $stderr << "Adding header #{key}, #{val}"
                    @response[key] = val
                end
                #@controller._wrote
                @controller._written = true
                @response.status = @controller.status || 200
                #@server_thread.run()
                self.instance_eval do
                    remove_instance_variable(:@controller)
                    #remove_instance_variable(:@server_thread)
                    remove_instance_variable(:@response)
                end
                $stderr << "written"
                super
                $stderr << "called super"
            end

            $stdout = w
            controllerThread = Thread.start do
                begin
                    $stderr << "dispatching"
                    controller.dispatch(path, env)
                    p "dispatched"
                rescue => exc
                    status = 401
                    headers = {}
                    body = 'Error: '
                    trace = exc.backtrace()
                    trace.each do |trace_line|
                        parts = trace_line.split(':')
                        file_path = parts[0]
                        line = parts[1]
                        method = parts[2]
                        body += "<li>"
                        body += "<a href='file://#{file_path}'>#{file_path}</a>:#{line}:#{method}"
                        body += "</li>"
                    end
                ensure
                    $stdout = STDOUT
                    $stderr << "Closing stream\n"
                    controller._written = true
                    w.close
                end
            end
            while (!controller._written)
                sleep(0.1) 
                $stderr << "not written"
            end
            $stderr << "\nReturning\n"
        end
    end


end; end