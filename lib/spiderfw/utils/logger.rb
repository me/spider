require 'logger'

module Spider
    
    module Logger
        
        class << self
            
            # def [](dest)
            #     @@loggers ||= {}
            #     @@loggers[dest]
            # end
        
            def open(dest, level= :WARN)
                @loggers ||= {}
                logger = ::Logger.new(dest)
                logger.level = ::Logger.const_get(level)
                @loggers[dest] = logger
            end
            
            def reopen(dest, level= :WARN)
                raise RuntimeError, "No open logger for #{dest}" unless @loggers && @loggers[dest]
                @loggers.delete(dest)
                self.open(dest, level)
            end
                
        
            def send_to_loggers(action, *args)
                return if $SAFE > 1
                return unless @loggers
                @loggers.each{ |dest, logger| logger.send(action, *args) }
            end
        
            def debug(*args)
                send_to_loggers(:debug, *args)
            end
        
            def info(*args)
                send_to_loggers(:info, *args)
            end
        
            def warn(*args)
                send_to_loggers(:warn, *args)
            end
            
            def error(*args)
                send_to_loggers(:error, *args)
            end

        end
        
        def debug(*args)
            Spider::Logger.debug(*args)
        end
        
        def info(*args)
            Spider::Logger.info(*args)
        end
        
        def warn(*args)
            Spider::Logger.warn(*args)
        end
        
        def error(*args)
            Spider::Logger.error(*args)
        end
        
        
    end
    
end
