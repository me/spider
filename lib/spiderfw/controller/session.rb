require 'uuid'

module Spider
    

    
    class Session
        attr_reader :sid
        
        def self.get(sid=nil)
            klass = nil
            case Spider.conf.get('session.store')
            when 'db'
            when 'memcached'
            when 'file'
                klass = FileSession
            else
                klass = MemorySession
            end
            klass.setup
            return klass.new(sid)
        end
        
        def self.setup
            return if @setup
            @setup = true
        end
        
        def self.check_purge
            if (!@last_purge || (Time.now - @last_purge) > Spider.conf.get('session.purge_check'))
                purge(Spider.conf.get('session.life'))
                @last_purge = Time.now
            end
        end
        
        def self.purge
            raise RuntimeError, "Unimplemented"
        end
        
        def initialize(sid=nil)
            @sid = sid || generate_sid
            restore
            @data ||= {}
        end
        
        def generate_sid
            UUID.new.generate
        end
        
        def restore
        end
        
        def persist
        end
        
        def [](key)
            @data[key]
        end
        
        def []=(key, val)
            @data[key] = val
        end
        
        def delete(key)
            @data.delete(key)
        end
        
        def persist
            self.class[@sid] = @data
        end
        
        def restore
            @data = self.class[@sid]
        end
        
        
    end
    
    
end