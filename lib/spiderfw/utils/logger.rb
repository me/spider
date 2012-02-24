require 'logger'
require 'zlib'

module Spider
    
    # Utility to consolidate many loggers into one. Can be used as a simple Logger,
    # and will pass log messages to each of its child.
    
    module Logger
        @@levels = [:DEBUG, :WARN, :INFO, :ERROR]
        
        class << self
            
            # def [](dest)
            #     @@loggers ||= {}
            #     @@loggers[dest]
            # end
            
            @loggers = {}
        
            # Open a new logger.
            def open(dest, level= :WARN)
                begin
                    logger = Spider::Logger::Logger.new(dest, Spider.conf.get('log.rotate.age'), Spider.conf.get('log.rotate.size'))
                    logger.formatter = Spider::Logger::Formatter.new
                    logger.level = ::Logger.const_get(level)
                    add(dest, logger)
                rescue => exc
                    STDERR << "Can't open logging to #{dest}: #{exc}\n"
                end
            end
            
            def add(dest, logger, levels={})
                @loggers[dest] = logger
            end
            
            # Close the given logger
            def close(dest)
                #raise RuntimeError, "No open logger for #{dest}" unless @loggers && @loggers[dest]
                @loggers.delete(dest)
            end
            
            # Closes all loggers.
            def close_all
                @loggers = {}
            end
            
            # Closes and reopens a logger.
            def reopen(dest, level= :WARN)
                raise RuntimeError, "No open logger for #{dest}" unless @loggers && @loggers[dest]
                @loggers.delete(dest)
                self.open(dest, level)
            end
                
            # Sends a method to all loggers.
            def send_to_loggers(action, *args, &proc)
                return if $SAFE > 1
                return unless @loggers
                return if request_level && !check_request_level(action)
                @loggers.each do |dest, logger| 
                    begin
                        logger.send(action, *args, &proc) 
                    rescue => exc
                    end
                end
            end
            
            def enquire_loggers(method)
                @loggers.each{ |dest, l| return true if l.send(method) }
                return false                
            end
            
            def log(*args, &proc)
                send_to_loggers(:add, *args, &proc)
            end
            
            def debug(*args, &proc)
                send_to_loggers(:debug, *args, &proc)
            end
            
            def debug?
                enquire_loggers(:debug?)
            end

            def info(*args, &proc)
                send_to_loggers(:info, *args, &proc)
            end
            
            def info?
                enquire_loggers(:info?)
            end
        
            def warn(*args, &proc)
                send_to_loggers(:warn, *args, &proc)
            end
            
            def warn?
                enquire_loggers(:warn?)
            end
            
            
            def error(*args, &proc)
                send_to_loggers(:error, *args, &proc)
            end
            
            def error?
                enquire_loggers(:error?)
            end
            
            def fatal(*args, &proc)
                send_to_loggers(:fatal, *args, &proc)
            end
            
            def fatal?
                enquire_loggers(:fatal?)
            end
            
            def datetime_format
                @loggers.each do |d, l|
                    return l.datetime_format
                end
            end
            
            def datetime_format=(datetime_format)
                @loggers.each do |d, l|
                    l.datetime_format=(datetime_format)
                end
            end
            
            def unknown(*args, &proc)
                send_to_loggers(:unknown, *args, &proc)
            end
            
            def method_missing(method, *args, &proc)
                send_to_loggers(method, *args, &proc)
            end

            def set_request_level(level)
                prev = Spider.current[:spider_logger_level]
                Spider.current[:spider_logger_level] = @@levels.index(level)
                return prev
            end

            def request_level
                Spider.current[:spider_logger_level]
            end

            def check_request_level(action)
                tl = request_level
                return unless tl
                action_i = @@levels.index(action.to_s.upcase.to_sym)
                return action_i >= tl
            end


        end
        
        def log(*args, &proc)
            Spider::Logger.add(*args, &proc)
        end
        
        def debug(*args, &proc)
            Spider::Logger.debug(*args, &proc)
        end
        
        def info(*args, &proc)
            Spider::Logger.info(*args, &proc)
        end
        
        def warn(*args, &proc)
            Spider::Logger.warn(*args, &proc)
        end
        
        def error(*args, &proc)
            Spider::Logger.error(*args, &proc)
        end
        
        def fatal(*args, &proc)
            Spider::Logger.fatal(*args, &proc)
        end
        
        def unknown(*args, &proc)
            Spider::Logger.unknown(*args, &proc)
        end
        
        def debug?
            Spider::Logger.debug?
        end
        
        def info?
            Spider::Logger.info?
        end
        
        def warn?
            Spider::Logger.warn?
        end
        
        def error?
            Spider::Logger.error?
        end
        
        def fatal?
            Spider::Logger.fatal?
        end
        
        
        class Formatter < ::Logger::Formatter
            Format = "%s, [%s#%d:%d] %5s -- %s: %s\n"
            
            def call(severity, time, progname, msg)
                Format % [severity[0..0], format_datetime(time), $$, Thread.current.object_id, severity, progname,
                msg2str(msg)]
            end
            
        end
        
        class Logger < ::Logger
            def initialize(logdev, shift_age=0, shift_size=1048576)
                super(nil, shift_age, shift_size)
                if logdev
                  @logdev = Spider::Logger::LogDevice.new(logdev, :shift_age => shift_age,
                    :shift_size => shift_size)
                end
            end
        end
        
        class LogDevice < ::Logger::LogDevice
            
            def shift_log_period(now)
                super
                postfix = previous_period_end(now).strftime("%Y%m%d")	# YYYYMMDD
                if Spider.conf.get('log.gzip')
                    gzip_filename = "#{@filename}.#{postfix}.gz"
                    f = File.open("#{@filename}.#{postfix}")
                    Zlib::GzipWriter.open(gzip_filename) do | gzip|
                        f.each do |line|
                            gzip << line
                        end
                    end
                    File.unlink("#{@filename}.#{postfix}")
                    f.close
                end
                if keep = Spider.conf.get('log.keep')
                    dir = File.dirname(@filename)
                    basename = File.basename(@filename)
                    dates = []
                    zipped = {}
                    Dir.glob(File.join(dir, "#{basename}.*")).each do |logfile|
                        name = File.basename(logfile)
                        if logfile =~ /\.(\d+)(\.gz)?$/
                            dates << $1
                            zipped[$1] = $2
                        end
                    end
                    (dates - dates.sort.reverse[0..keep-1]).each do |d|
                        fname = "#{@filename}.#{d}"
                        fname += ".gz" if zipped[d]
                        File.unlink(fname)
                    end
                end
                return true
            end
            
            def shift_log_age
                super
                (@shift_age-3).downto(0) do |i|
                    if FileTest.exist?("#{@filename}.#{i}.gz")
                        File.rename("#{@filename}.#{i}.gz", "#{@filename}.#{i+1}.gz")
                    end
                end
                if Spider.conf.get('log.gzip')
                    gzip_filename = "#{@filename}.0.gz"
                    f = File.open("#{@filename}.0")
                    Zlib::GzipWriter.open(gzip_filename) do | gzip|
                        f.each do |line|
                            gzip << line
                        end
                    end
                    File.unlink("#{@filename}.0")
                    f.close
                end
                if keep = Spider.conf.get('log.keep')
                    dir = File.dirname(@filename)
                    basename = File.basename(@filename)
                    Dir.glob(File.join(dir, "#{basename}.*")).each do |logfile|
                        name = File.basename(logfile)
                        if logfile =~ /\.(\d+)(\.gz)?$/
                            File.unlink(logfile) if $1.to_i >= Spider.config.get('log.keep')
                        end
                    end
                end
                return true
            end
            
        end
        
    end
    
end
