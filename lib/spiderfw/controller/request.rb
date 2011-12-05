module Spider
    
    class Request
        attr_accessor :action, :params, :cookies, :env, :protocol,
                      :format, :session, :user_id, :server, :request_time, :controller_path,
                      :locale, :misc
                      
        BUFSIZE = 1024*4
        
        def self.current
            Thread.current[:spider_request] ||= {}
        end
        
        def self.current=(val)
            Thread.current[:spider_request] = val
        end
        
        def self.reset_current
            Thread.current[:spider_request] = nil
        end
        
        
        def initialize(env)
            @env = env
            @locale = Spider.locale
            @misc = {}
            @params = {}
            @action = ""
            @session = {}
        end
        
        def body=(b)
            @body = b
        end
        
        def body
            b = @body.is_a?(String) ? StringIO.new(@body) : @body
            return nil unless b
            if block_given?
                b.rewind
                while (buf = b.read(BUFSIZE))
                    yield buf
                end
            end
            return b
        end
        
        
        def read_body
            return @body if @body.is_a?(String)
            b = ''
            self.body do |buf|
                b += buf
            end
            @body = b
        end
        
        # Original request path
        def path
            @action
        end
            
        
    end
    
end
