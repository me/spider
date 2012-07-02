require 'spiderfw/controller/request'
require 'spiderfw/controller/http_controller'

module Spider; module HTTP
    
    class RackRequest < Spider::Request
        attr_accessor :rack_input
        
        
        def body(&proc)
            if block_given?
                @rack_input.each{ |buf| yield buf }
            else
                @rack_input
            end
        end
        
        
    end
    
    class RackIO < ControllerIO

        def initialize(response, controller_response, w, options={})
            @response = response
            @controller_response = controller_response
            @w = w
            @headers_sent = false
            @rack_thread = Thread.current
            @options = options
        end

        def write(msg)
            send_headers unless @headers_sent
            @w.write(msg)
        end

        def send_headers
            Spider::Logger.debug("---SENDING HEADERS----")
            @controller_response.prepare_headers
            @response[:status] = @controller_response.status
            @response[:headers] = {}
            @controller_response.headers.each do |key, val|
                if (val.is_a?(Array))
                    val.each{ |v| @response[:headers][key] = v.to_s }
                else
                    @response[:headers][key] = val.to_s
                end
            end
            @headers_sent = true
            @rack_thread.run if @options[:multithread]
        end

        def headers_sent?
            @headers_sent
        end
        
        def set_body_io(io)
            return super if headers_sent?
            begin
                @response[:body].close
            rescue => exc
            end
            @response[:body] = io
            send_headers
        end


        def flush
        end

    end
    
    class RackApplication

        def call(env)
            Spider.request_started
            env = prepare_env(env)
            controller_request = RackRequest.new(env)
            controller_request.server = RackApplication
            controller_request.rack_input = env['rack.input']
            path = env['PATH_INFO'].chomp('/')
            controller_request.action = path
            controller_request.request_time = DateTime.now

            w = nil
            controller_response = Spider::Response.new
            if RUBY_PLATFORM =~ /mingw32/
                multithread = false
            else    
                multithread = env['rack.multithread'] || Spider.conf.get('webserver.force_threads')
            end
            if multithread
                r, w = IO.pipe
                rack_response_hash = {:body => r}
                controller_response.server_output = RackIO.new(rack_response_hash, controller_response, w, :multithread => true)
            else
                w = StringIO.new
                rack_response_hash = {:body => w}
                controller_response.server_output = RackIO.new(rack_response_hash, controller_response, w)
            end


            controller = nil
            controller_done = false

            run_block = lambda do
                begin
                    controller = ::Spider::HTTPController.new(controller_request, controller_response)
                    controller.extend(Spider::FirstResponder)
                    controller.call_before(path)
                    controller.execute(path)
                    if multithread
                        w.close 
                        controller_response.server_output.send_headers unless controller_response.server_output.headers_sent?
                    end
                    controller.call_after(path)
                    controller_done = true
                rescue Exception => exc
                    Spider.logger.error(exc)
                    controller.ensure if controller
                    controller = nil
                ensure
                    begin
                        if multithread
                            controller_response.server_output.send_headers unless controller_response.server_output.headers_sent?
                        else
                            controller_response.prepare_headers
                            rack_response_hash[:status] = controller_response.status
                            rack_response_hash[:headers] = {}
                            controller_response.headers.each do |key, val|
                                if (val.is_a?(Array))
                                    val.each{ |v| rack_response_hash[:headers][key] = v.to_s }
                                else
                                    rack_response_hash[:headers][key] = val.to_s
                                end
                            end
                            w.rewind
                        end
                        Spider.request_finished
                    ensure
                        if multithread
                           begin
                               w.close
                           rescue
                           end
                           Spider.remove_thread(Thread.current)
                           Thread.exit 
                        end
                    end
                end
            end
            
            if multithread
                controllerThread = Thread.start(&run_block)
                t = Time.now
                while !controller_done && !controller_response.server_output.headers_sent? && (Time.now - t) < 60
                    Thread.stop
                end
                if (Time.now - t) >= 60
                    controllerThread.kill
                end
                Spider.add_thread(controllerThread) unless controller_done
            else
                run_block.call
            end

            return [rack_response_hash[:status], rack_response_hash[:headers], rack_response_hash[:body]]
        end
        
        def prepare_env(env)
            env['HTTP_CONTENT_TYPE'] = env['CONTENT_TYPE']
            return env
        end
        
        def initialize_server
            Spider.startup
        end
        
        def finalize_server
            Spider.shutdown
        end
        
    end
    
end; end
    
