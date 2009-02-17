module Spider; module Helpers
    
    module HTTP
        MULTIPLE_CHOICHES = 300
        MOVED_PERMANENTLY = 301
        FOUND = 302
        SEE_OTHER = 303
        TEMPORARY_REDIRECT = 307
        
        def redirect(url, code=MOVED_PERMANENTLY)
            debug "REDIRECTING TO #{url}"
            @response.status = 301
            @response.headers["Location"] = url
            @response.headers.delete("Content-Type")
            @response.headers.delete("Set-Cookie")
            done
        end
        
        def before(action='', *arguments)
            if (action == '')
                check_controller = @dispatch_previous
                dispatched_action = check_controller.dispatched_action
                while (!dispatched_action || dispatched_action.empty?)
                    check_controller = check_controller.dispatch_previous
                    dispatched_action = check_controller.dispatched_action
                end
                dispatched_action ||= ''
                if (dispatched_action == '' || dispatched_action[-1].chr != '/')
                    if (dispatched_action =~ /\/([^\/]+)$/)
                        dispatched_action = $1
                    end
                    dest = dispatched_action+'/'
                    if (@request.env['QUERY_STRING'] && !@request.env['QUERY_STRING'].empty?)
                        dest += '?'+@request.env['QUERY_STRING']
                    end
                    redirect(dest)
                end
            end
            super
        end
        
    end
    
    
end; end