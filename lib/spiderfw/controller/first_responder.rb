module Spider
    
    module FirstResponder
        
        def before(action='', *arguments)
            # if (Spider.conf.get('profiling.enable') && @request.env['QUERY_STRING'] =~ /profile=true/)
            #     unless Spider.request_mutex
            #         Spider.mutex_requests!
            #         Spider.request_mutex.lock
            #     end
            #     require 'ruby-prof'
            #     RubyProf.start
            #     @profiling_started = true
            # end
            catch :done do
                begin
                    super
                rescue => exc
                    try_rescue(exc)
                end
            end
        end
        
        def execute(action='', *arguments)
            catch :done do
                begin
                    super
                rescue => exc
                    try_rescue(exc)
                end
            end
        end
        
        def after(action='', *arguments)
            catch :done do
                begin
                    super
                rescue => exc
                    try_rescue(exc)
                end
            end
            # if (@profiling_started)
            #     debugger
            #     Spider.request_mutex.unlock
            #     Spider.request_mutex = nil
            #     result = RubyProf.stop
            #     printer = ::RubyProf::GraphHtmlPrinter.new(result)
            #     file_name = Spider.paths[:tmp]+"/prof_#{DateTime.now.to_s}.html"
            #     File.open(file_name, 'w') do |f|
            #         printer.print(f, :min_percent => 0)
            #     end
            #     Spider.logger.info("Written profiling info in #{file_name}")
            # end
            
        end
        
        
    end
    
end