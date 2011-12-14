$:.push(ENV['SPIDER_PATH']+'/lib')
require 'spiderfw/init'
require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/http_controller'
require 'spiderfw/http/adapters/cgi_io'

module Spider; module HTTP
    class CGIServer < Server
        @supports = {
            :chunked_request => false
        }
    end
end; end

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
controller_request = Spider::Request.new(env)
controller_request.server = Spider::HTTP::CGIServer
controller_request.body = body
path = env['REQUEST_PATH']+''
controller_request.action = path
controller_response = Spider::Response.new
controller_response.server_output = CGIIO.new(STDOUT, controller_response)
begin
    controller = ::Spider::HTTPController.new(controller_request, controller_response)
    controller.call_before(path)
    controller.execute(path)
    controller.call_after(path)                
rescue => exc
    Spider.logger.error(exc)
    controller.ensure()
ensure
    controller_response.server_output.send_headers unless controller_response.server_output.headers_sent
end