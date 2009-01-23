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
            return klass.new(sid)
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
        
        def persist
            self.class[@sid] = @data
        end
        
        def restore
            @data = self.class[@sid]
        end
        
        
    end
    
    
end