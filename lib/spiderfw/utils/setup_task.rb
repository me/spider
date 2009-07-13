module Spider
    
    # TODO: remove?
    class SetupTask #:nodoc:
        
        # FIXME: concurrency?
        def self.current_task=(task)
            @current_task = task
        end
        
        def self.current_task
            @current_task
        end
        
        def self.inherited(subclass)
            Spider::SetupTask.current_task = subclass
        end
        
        def run
        end
        
        def rollback
            raise SetupError, "Rollback not implemented for SetupTask #{self.class}"
        end
        
        def done
            Spider::SetupTask.current_task = nil
        end
        
    end
    
    class SetupError < RuntimeError
    end
    
end