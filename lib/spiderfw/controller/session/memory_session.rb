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
                    @sessions[sid] ? @sessions[sid][:data] : nil
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
            
            def delete(sid)
                @mutex.synchronize{
                    @sessions.delete(sid)
                }
            end
            
        end
        
        
        def restore
            @data = self.class[@sid]
        end
        
        
    end
    
    
end