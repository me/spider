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
            def send_to_loggers(action, *args)
                return if $SAFE > 1
                return unless @loggers
                @loggers.each do |dest, logger| 
                    begin
                        logger.send(action, *args) 
                    rescue => exc
                    end
                end
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
