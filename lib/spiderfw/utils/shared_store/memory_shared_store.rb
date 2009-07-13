require 'spiderfw/utils/shared_store'

module Spider; module Utils
    
    # Implementation of the SharedStore in memory.
    # This is a transient, per-process, thread safe store. (See SharedStore about thread safety).
    class MemorySharedStore < SharedStore
        
        def initialize(config={})
            super
            @data = {}
            @sync = Sync.new
        end
        
        def [](key)
            @sync.lock(:SH)
            res = @data[key]
            @sync.lock(:UN)
            return res
        end
        
        def []=(key, value)
            @sync.lock(:EX)
            @data[key] = value
            @sync.lock(:UN)
        end
        
        def delete(key)
            @sync.lock(:EX)
            @data.delete(key)
            @sync.lock(:UN)
        end
        
        def include?(key)
            @data.include?(key)
        end
        
        def each_key
            @data.keys.each do |k|
                yield k
            end
        end
        
    end
    
end; end