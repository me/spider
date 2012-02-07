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
        
        def no_cookies
            @no_cookies = true
        end
        
        def prepare_headers
            unless @no_cookies
                @headers['Set-Cookie'] ||= []
                @cookies.each do |k, v|
                    h = "#{k}=#{v}"
                    h += '; expires='+v.expires.strftime("%a, %b %d %Y %H:%M:%S %Z") if (v.expires.respond_to?(:strftime))
                    h += "; path=#{v.path}" if (v.path)
                    h += "; domain=#{v.domain}" if (v.domain)
                    h += "; secure" if (v.secure)
                    @headers['Set-Cookie'] << h
                end
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

        def buffering?
            @prev_io != nil
        end

        def start_buffering
            @buffer = StringIO.new
            @prev_io = ThreadOut.output_to(@buffer)
        end

        def stop_buffering
            ThreadOut.output_to(@prev_io)
            @prev_io = nil
            @buffer.rewind
        end

        def output_buffer
            stop_buffering if buffering?
            return unless @buffer
            while d = @buffer.read(1024)
                $out << d
            end
            buffer = @buffer
            @buffer = nil
            buffer
        end

        def buffer
            @buffer
        end

        def clear_buffer
            @buffer = nil
        end

        def content_type=(val)
            @headers['Content-Type'] = val
        end

        def content_type
            @headers['Content-Type']
        end

        def content_length=(val)
            @headers['Content-Length'] = val
            if @buffer_until_length && val
                output_buffer
                @buffer_until_length = false
            end
        end

        def content_length
            @headers['Content-Length']
        end

        def buffer_until_length
            unless content_length
                start_buffering
                @buffer_until_length = true
            end
        end

        def finish!
            if buffering?
                stop_buffering
                needs_length = @needs_length
                self.content_length = @buffer.length
                output_buffer unless needs_length
            end
        end

        def connection_keep_alive
            @headers['Connection'] = 'Keep-Alive'
            buffer_until_length unless Spider.conf.get('webserver.has_buffering_proxy')
        end

        def do_not_buffer!
            unless Spider.conf.get('webserver.has_buffering_proxy')
                @headers['Connection'] = 'Close'
            end
            output_buffer
            @buffer_until_length = false
        end


        
    end
    
    
end