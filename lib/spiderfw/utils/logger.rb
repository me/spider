require 'logger'

module Spider
    
    module Logger
        
        class << self
        
            def open(dest, level=:WARN)
                @@loggers ||= []
                logger = ::Logger.new(dest)
                logger.level = ::Logger.const_get(level)
                @@loggers << logger
            end
        
            def send_to_loggers(action, *args)
                return unless @@loggers
                @@loggers.each{ |logger| logger.send(action, *args) }
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