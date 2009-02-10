require 'spiderfw/controller/session'

module Spider
    
    class MemorySession < Session
        
        class << self
                
            
            def setup
                unless @sessions
                    @mutex ||= Mutex.new
                    @sessions ||= Hash.new
                end
                super
            end
        
            def []=(sid, data)
                @mutex.synchronize {
                    @sessions[sid] = {
                        :data => data,
                        :mtime => Time.now
                    }
                }
            end
        
            def [](sid)
                check_purge
                @mutex.synchronize{
                    @sessions[sid]
                }
            end
            
            def purge(life)
                @mutex.synchronize{
                    @sessions.each do |sid, session|
                        if (session[:mtime] + life < Time.now)
                            @sessions.delete(sid)
                        end
                    end
                }
            end
            
        end
        
        
        def persist
            Spider::Logger.debug("Persisting session #{@sid}")
            self.class[@sid] = @data
        end
        
        def restore
            sess = self.class[@sid] || {}
            @data = sess[:data]
            @mtime = sess[:mtime]
        end
        
        
    end
    
    
end