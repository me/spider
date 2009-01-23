require 'spiderfw/controller/session'

module Spider
    
    class MemorySession < Session
        
        class << self
                
            
            def setup
                unless @sessions
                    @mutex ||= Mutex.new
                    @sessions ||= Hash.new
                end
            end
        
            def []=(sid, data)
                setup
                @mutex.synchronize {
                    @sessions[sid] = data
                }
            end
        
            def [](sid)
                setup
                @mutex.synchronize{
                    @sessions[sid]
                }
            end
            
        end
        
        
        def persist
            self.class[@sid] = @data
        end
        
        def restore
            @data = self.class[@sid]
        end
        
        
    end
    
    
end