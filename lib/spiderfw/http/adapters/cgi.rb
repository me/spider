$:.push(ENV['SPIDER_PATH']+'/lib')
require 'spiderfw'
require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/http_controller'
require 'cgi'

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
        @headers_sent = true
        @out << "Status: #{@controller_response.status}\n"
        @controller_response.headers.each do |key, val|
            @out << "#{key}: #{val}\n"
        end
        @out << "\n"
    end
    
    
end

def prepare_params
    return {
        'SERVER_NAME' => ENV['SERVER_NAME'],
        'PATH_INFO' => ENV['PATH_INFO'],
        'HTTP_ACCEPT_ENCODING' => ENV['HTTP_ACCEPT_ENCODING'],
        'HTTP_USER_AGENT' => ENV['HTTP_USER_AGENT'],
        'SCRIPT_NAME' => ENV['SCRIPT_NAME'],
        'SERVER_PROTOCOL' => ENV['SERVER_PROTOCOL'],
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
controller_request = Spider::Request.new
controller_request.env = prepare_params
if (controller_request.env['REQUEST_METHOD'] == 'POST')
    body = $stdin.read(controller_request.env['CONTENT_LENGTH'].to_i)
    Spider::Logger.debug("CGI POST BODY: #{body}")
    controller_request.parse_query(body)
else
    controller_request.parse_query(controller_request.env['QUERY_STRING'])
end
controller_request.protocol = :http
path = controller_request.env['REQUEST_PATH']+''
controller_response = Spider::Response.new
controller_response.body = CGIIO.new($stdout, controller_response)
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