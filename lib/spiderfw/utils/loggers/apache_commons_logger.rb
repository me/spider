module Spider; module Loggers
    
    class ApacheCommonsLogger
        
        def initialize(klass='spider')
            @logger = org.apache.commons.logging.LogFactory.getLog(klass)
        end
        
        def do_log(level, message=nil, &proc)
            if block_given?
                return unless send("#{level}?")
        	    message = yield
    	    end
            @logger.send(level, message)
        end
        
        def fatal(message, &proc)
            do_log(:fatal, message, &proc)
        end
        
        def error(message, &proc)
            do_log(:error, message, &proc)
        end
        
        def warn(message, &proc)
            do_log(:warn, message, &proc)
        end
        
        def info(message, &proc)
            do_log(:info, message, &proc)
        end
        
        def debug(message, &proc)
            do_log(:info, message, &proc)
        end
        
        def fatal?
            @logger.isFatalEnabled
        end
        
        def error?
            @logger.isErrorEnabled
        end
        
        def warn?
            @logger.isWarnEnabled
        end
        
        def info?
            @logger.isInfoEnabled
        end
        
        def debug?
            @logger.isDebugEnabled
        end
        
        
        
    end
    
end; end