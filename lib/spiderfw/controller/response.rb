require 'spiderfw/controller/cookies'

module Spider
    
    class Response
        attr_reader :status
        attr_accessor :headers, :server_output, :cookies
        
        def initialize()
            @headers = {}
            @cookies = Cookies.new
        end
        
        def body=(io)
            @server_output.set_body_io(io)
        end
        
        def register(key, val)
            instance_variable_set("@#{key}", val)
            self.class.send(:attr_accessor, key) # FIXME: threadsafety
        end
        
        def prepare_headers
            @headers['Set-Cookie'] ||= []
            @cookies.each do |k, v|
                h = "#{k}=#{v}"
                h += '; expires='+v.expires.strftime("%a, %b %d %Y %H:%M:%S %Z") if (v.expires.respond_to?(:strftime))
                h += "; path=#{v.path}" if (v.path)
                h += "; domain=#{v.domain}" if (v.domain)
                h += "; secure" if (v.secure)
                @headers['Set-Cookie'] << h
            end
            Spider::Logger.debug("HEADERS:")
            Spider::Logger.debug(@headers)
        end
        
        def status=(code)
            @status = code
            # if (Spider::HTTP.status_messages[code])
            #     @status = code.to_s+' '+Spider::HTTP.status_messages[code]
            # else
            #     @status = code
            # end
        end

        
    end
    
    
end