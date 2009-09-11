module Spider
    
    class Request
        attr_accessor :action, :params, :cookies, :env, :protocol,
                      :format, :extension, :session, :user_id, :server, :request_time, :controller_path,
                      :locale
                      
        BUFSIZE = 1024*4
        
        
        def initialize(env)
            Spider::Logger.debug("REQUEST:")
            Spider::Logger.debug(env)
            @env = env
            @locale = Spider.locale
        end
        
        def body=(b)
            @body = b
        end
        
        def body(&proc)
            b = @body.is_a?(String) ? StringIO.new(@body) : @body
            return nil unless b
            while (buf = b.read(BUFSIZE))
                yield buf
            end
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