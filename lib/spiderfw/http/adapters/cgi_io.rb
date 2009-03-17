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
        Spider::Logger.debug("CGI sending headers:")
        @controller_response.prepare_headers
        @headers_sent = true
        @out << "Status: #{@controller_response.status}\n"
        @controller_response.headers.each do |key, val|
            @out << "#{key}: #{val}\n"
        end
        @out << "\n"
    end
    
    
end