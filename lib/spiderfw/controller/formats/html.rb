require 'spiderfw/controller/controller_mixin'

module Spider
    
    module HTML
        include ControllerMixin
        
        # before do
        #     Spider.logger.debug('HTML before')
        #     #@response.headers['Content-Type'] = 'text/html'
        #    
        #     begin
        #         run_chain(:before)
        #     # rescue NotFound
        #     #     render('errors/404')
        #     rescue => exc
        #         top
        #         print_backtrace(exc)
        #         bottom
        #         raise exc
        #     end 
        # end
        
        def before(action='', *arguments)
            Spider.logger.debug("HTML BEFORE")
            @response.register(:js, [])
            begin
                super
            rescue => exc
                top
                print_backtrace(exc)
                bottom
                raise exc
            end
        end
        
        execute do
            #top
            run_chain(:execute)
        end
        
        after do
            run_chain(:after)
            #bottom
        end
        
        def top
            puts "<html>"
            puts "<head>"
            @response.js.each do |js|
                puts "<script type=\"text/javascript\" src=\"#{js}\"></script>"
            end
            puts "</head>"
            puts "<body>" 
        end
        
        def bottom
            puts "</body></html>"
        end
        
        def try_rescue(exc)
            print_backtrace(exc) if Spider.config.get('webserver.show_traces')
            raise exc
        end
        
        
        def print_backtrace(exc)
            html = "<h3>Error: "+exc.to_s+"</h3>"
            html += "<ul>"
            client_editor = (Spider.config.get('client.text_editor') || '').downcase
            prefix = ''
            prefix = 'txmt://open?url=' if (client_editor == 'textmate')
            exc.backtrace.each do |trace_line|
                parts = trace_line.split(':')
                file_path = parts[0]
                line = parts[1]
                method = parts[2]
                suffix = ''
                suffix = '&line='+line if (client_editor == 'textmate')
                html += "<li>"
                html += "<a href='#{prefix}file://#{file_path}#{suffix}'>#{file_path}</a>:#{line}:#{method}"
                html += "</li>"
            end
            html += "</ul>"
            puts html
        end
        
    end
    
end