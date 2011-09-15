module Spider
    
    module EventSource
        
        def self.included(klass)
            klass.extend(ClassMethods)
        end
        
        module ClassMethods
            
            def inherited(sub)
                if @event_handlers
                    @event_handlers.each do |event_name, arr|
                        arr.each do |proc|
                            sub.on(event_name, &proc)
                        end
                    end
                end
                super
            end
        
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
        
        def on(event_name, *params, &proc)
            @event_handlers ||= {}
            @event_handlers[event_name] ||= []
            @event_handlers[event_name] << proc
        end
        
        def trigger(event_name, *params)
            self.class.trigger(event_name, *([self]+params))
            return unless @event_handlers && @event_handlers[event_name]
            @event_handlers[event_name].each do |h|
                h.call(*params)
            end
        end
        
    end
    
end