module Spider; module HTTP; module Rack
    
    class Application
        
        def initialize
        end
        
        def call(env)
           path = env['PATH_INFO'] ? env['PATH_INFO'].chomp('/') : ''
           controller, rel_path = ::Spider::Controller.route(path, env)
           r, w = IO.pipe
           
           status = nil
           headers = controller.headers
           $stdout = w
#           body = r
           
#            w.instance_eval { alias :_old_write :write }
# #           w.instance_variable_set(:@server_thread, mainThread)
#            w.instance_variable_set(:@controller, controller)
#            
#            $stderr << "Test stderr\n"
#            def w.write(s)
#                $stderr << "Written #{s}!\n"
#                $stderr << "Current thread:\n"
#                $stderr << Thread.current
#                self.instance_eval do
#                    alias :write :_old_write
#                end
#  #               $stderr << "Pre wakeup"
#  #                @server_thread.wakeup()
#  #                $stderr << "Pre run"
#  #                @server_thread.run()
#  #                $stderr << "Runned"
#  # #               @server_thread.join()
#  #                $stderr << "Joined"
#                 status = @controller.status
#                 headers = @controller.headers
#                 self.instance_eval do
# #                   remove_instance_variable(:@server_thread)
#                    remove_instance_variable(:@controller)
#                end
#                
#                super(s)
#            end
#            $stdout = w
           controllerThread = Thread.start do
               begin
                   controller.handle(rel_path, env)
               rescue => exc
                   status = 401
                   headers = {}
                   body = 'Error: '
                   trace = exc.backtrace()
                   trace.each do |trace_line|
                       parts = trace_line.split(':')
                       file_path = parts[0]
                       line = parts[1]
                       method = parts[2]
                       body += "<li>"
                       body += "<a href='file://#{file_path}'>#{file_path}</a>:#{line}:#{method}"
                       body += "</li>"
                   end
               ensure
                   $stderr << "Ensuring"
                   $stdout = STDOUT
                   w.close
               end
           end
           return [200, headers, r]
           
        end
        
    end
    
    
end; end; end