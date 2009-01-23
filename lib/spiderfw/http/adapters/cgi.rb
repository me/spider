$:.push(ENV['SPIDER_PATH']+'/lib')
require 'spiderfw'
require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/http_controller'

class CGIIO < Spider::ControllerIO
    attr_reader :headers_sent
    
    def initialize(out, controller_response)
        @out = out
        @controller_response = controller_response
        @headers_sent = false
    end
    
    def write(msg)
        send_headers unless @headers_sent
        @out << msg
    end
    
    def send_headers
        Spider::Logger.debug("sending headers")
        @controller_response.prepare_headers
        @headers_sent = true
        @out << "Status: #{@controller_response.status}\n"
        @controller_response.headers.each do |key, val|
            @out << "#{key}: #{val}\n"
        end
        @out << "\n"
    end
    
    
end

def prepare_env
    return {
        'SERVER_NAME' => ENV['SERVER_NAME'],
        'PATH_INFO' => ENV['PATH_INFO'],
        'HTTP_ACCEPT_ENCODING' => ENV['HTTP_ACCEPT_ENCODING'],
        'HTTP_USER_AGENT' => ENV['HTTP_USER_AGENT'],
        'SCRIPT_NAME' => ENV['SCRIPT_NAME'],
        'SERVER_PROTOCOL' => ENV['SERVER_PROTOCOL'],
        'HTTP_COOKIE' => ENV['HTTP_COOKIE'],
        'HTTP_HOST' => ENV['HTTP_HOST'],
        'HTTP_ACCEPT_LANGUAGE' => ENV['HTTP_ACCEPT_LANGUAGE'],
        'SERVER_SOFTWARE' => ENV['SERVER_SOFTWARE'],
        'REQUEST_PATH' => ENV['REQUEST_PATH'],
        'HTTP_VERSION' => ENV['HTTP_VERSION'],
        'REQUEST_URI' => ENV['REQUEST_URI'],
        'SERVER_PORT' => ENV['SERVER_PORT'],
        'GATEWAY_INTERFACE' => ENV['GATEWAY_INTERFACE'],
        'HTTP_ACCEPT' => ENV['HTTP_ACCEPT'],
        'HTTP_CONNECTION' => ENV['HTTP_CONNECTION'],
        'REQUEST_METHOD' => ENV['REQUEST_METHOD'],
        'QUERY_STRING' => ENV['QUERY_STRING'],
        'CONTENT_TYPE' => ENV['CONTENT_TYPE'],
        'CONTENT_LENGTH' => ENV['CONTENT_LENGTH']
    }
end

Spider::Logger.debug('-----------')
env = prepare_env
body = $stdin.read(env['CONTENT_LENGTH'].to_i)
controller_request = Spider::Request.new(:http, env, body)
path = env['REQUEST_PATH']+''
controller_response = Spider::Response.new
controller_response.body = CGIIO.new(STDOUT, controller_response)
begin
    controller = ::Spider::HTTPController.new(controller_request, controller_response)
    #controller.before(path)
    controller.execute(path)
    #controller.after(path)                
rescue => exc
    Spider.logger.error(exc)
    controller.ensure()
ensure
    controller_response.body.send_headers unless controller_response.body.headers_sent
end