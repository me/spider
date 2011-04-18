module Spider
    
    module Profiling
        
        def self.start
            raise "Profiling already started" if @profiling_started
            unless Spider.request_mutex
                Spider.mutex_requests!
                Spider.request_mutex.lock
            end
            require 'ruby-prof'
            Spider.logger.debug("Starting profiling")
            @profiling_started = true
            RubyProf.start
        end
        
        def self.stop
            result = RubyProf.stop
            @profiling_started = false
            printer = ::RubyProf::GraphHtmlPrinter.new(result)
            file_name = Spider.paths[:tmp]+"/prof_#{DateTime.now.to_s}.html"
            File.open(file_name, 'w') do |f|
                printer.print(f, :min_percent => 0)
            end
            Spider.logger.info("Written profiling info in #{file_name}")
            Spider.request_mutex.unlock
            Spider.request_mutex = nil
        end
        
        def self.started?
            @profiling_started
        end
        
    end
    
end