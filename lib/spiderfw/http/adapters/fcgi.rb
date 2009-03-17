require 'fcgi'

require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/http_controller'
require 'spiderfw/http/adapters/cgi_io'

def prepare_env(env)
    return env
end

module Spider; module HTTP
    class FCGIServer < Server
        @supports = {
            :chunked_request => true
        }
    end
end; end

exit_graceful = false
set_grace = lambda do 
    STDERR << "RECEIVED SIGNAL\n";
    exit_graceful = true; 
    # result = RubyProf.stop
    # printer = RubyProf::FlatPrinter.new(result)
    # printer.print(STDERR, 0)
    exit
end
trap('SIGTERM', &set_grace) 
trap('SIGINT', &set_grace) 
trap('SIGQUIT', &set_grace) 
trap('SIGABRT', &set_grace) 

# require 'ruby-prof'
# RubyProf.start

FCGI.each_request do |req|
    env = prepare_env(req.env)
    body = req.in
    controller_request = Spider::Request.new(env)
    controller_request.server = Spider::HTTP::FCGIServer
    controller_request.body = body
    path = env['REQUEST_URI']+''
    controller_request.action = path
    controller_response = Spider::Response.new
    controller_response.server_output = CGIIO.new(req.out, controller_response)
#    controllerThread = Thread.start do
        begin
            controller = ::Spider::HTTPController.new(controller_request, controller_response)
            controller.before(path)
            controller.execute(path)
            controller.after(path)                
        rescue => exc
            Spider.logger.error(exc)
            controller.ensure()
        ensure
            controller_response.server_output.send_headers unless controller_response.server_output.headers_sent
            req.finish
        end
#    end
    break if exit_graceful
end

