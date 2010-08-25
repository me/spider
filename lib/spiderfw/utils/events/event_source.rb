module Spider
    
    module EventSource
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        module ClassMethods
        
            def on(event_name, &proc)
                @event_handlers ||= {}
                @event_handlers[event_name] ||= []
                @event_handlers[event_name] << proc
            end
        
            def trigger(event_name, *params)
                return unless @event_handlers && @event_handlers[event_name]
                @event_handlers[event_name].each do |h|
                    h.call(*params)
                end
            end
            
        end
        
        def trigger(event_name, *params)
            self.class.trigger(event_name, *([self]+params))
        end
        
    end
    
end