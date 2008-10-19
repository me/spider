require 'logger'

module Spider
    
    class Logger
        
        def initialize
            @loggers = []
        end
        
        def open(dest, level=:WARN)
            logger = ::Logger.new(dest)
            logger.level = ::Logger.const_get(level)
            @loggers << logger
        end
        
        def method_missing(name, *args)
            @loggers.each{ |logger| logger.send(name, *args) }
        end
        
    end
    
end