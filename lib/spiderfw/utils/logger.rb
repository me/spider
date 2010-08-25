require 'logger'

module Spider
    
    # Utility to consolidate many loggers into one. Can be used as a simple Logger,
    # and will pass log messages to each of its child.
    
    module Logger
        
        class << self
            
            # def [](dest)
            #     @@loggers ||= {}
            #     @@loggers[dest]
            # end
        
            # Open a new logger.
            def open(dest, level= :WARN)
                @loggers ||= {}
                logger = ::Logger.new(dest, Spider.conf.get('log.rotate.age'), Spider.conf.get('log.rotate.size'))
                logger.level = ::Logger.const_get(level)
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
                if args[0].is_a?(String)
                    args[0] = "T#{Thread.current.object_id} #{args[0]}"
                end
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
        
        
    end
    
end
