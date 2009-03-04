module Spider; module Helpers
    
    module HTTP
        
        def redirect(url, code=Spider::HTTP::MOVED_PERMANENTLY)
            debug "REDIRECTING TO #{url}"
            @response.status = code
            @response.headers["Location"] = url
            @response.headers.delete("Content-Type")
            @response.headers.delete("Set-Cookie")
            done
        end
        
        def before(action='', *arguments)
            # Redirect to url + slash if controller is called without action
            if (action == '' && @request.env['PATH_INFO'][-1].chr != '/')
                dest = @request.env['PATH_INFO']+'/'
                if (@request.env['QUERY_STRING'] && !@request.env['QUERY_STRING'].empty?)
                    dest += '?'+@request.env['QUERY_STRING']
                end
                redirect(dest)
            end
            super
        end
        
        def try_rescue(exc)
            if (exc.is_a?(HTTPStatus))
                @response.status = exc.code
                done
                #raise
            else
                super
            end
        end
        
        class HTTPStatus < RuntimeError
            attr_reader :code
            
            def initialize(code)
                @code = code
            end
            
            def status_message
                Spider::HTTP.status_messages[@code]
            end
        end
        
    end
    
    
end; end