require 'uuid'
require 'spiderfw/controller/session/flash_hash'
require 'spiderfw/controller/session/transient_hash'

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
            Spider::Logger.debug("SESSION RESTORED:")
            Spider::Logger.debug(@data)
            @data ||= {}
            @data[:_flash].reset if @data[:_flash]
        end
        
        def generate_sid
            UUID.new.generate
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
            clear_empty_hashes!(@data)
            @data[:_flash].purge if @data[:_flash]
            @data[:_transient].purge if @data[:_transient]
            # Spider::Logger.debug("PERSISTING SESSION:")
            # Spider::Logger.debug(@data)
            self.class[@sid] = @data
        end
        
        def restore
            @data = self.class[@sid]
        end
        
        def flash
            @data[:_flash] ||= FlashHash.new
        end
        
        def transient
            @data[:_transient] ||= TransientHash.new
        end
        
        def clear_empty_hashes!(h)
            h.each do |k, v|
                if (v.is_a?(Hash))
                    if (v.empty?)
                        h.delete(k)
                    else
                        clear_empty_hashes!(v)
                    end
                end
            end
        end
        
        
    end
    
    
end