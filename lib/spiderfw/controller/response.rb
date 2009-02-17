require 'spiderfw/controller/cookies'

module Spider
    
    class Response
        attr_accessor :status, :headers, :body, :cookies
        
        def initialize
            @headers = {}
            @cookies = Cookies.new
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

        
    end
    
    
end