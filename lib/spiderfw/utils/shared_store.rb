module Spider; module Utils
    
    class SharedStore
        
        def self.get(type=nil, config=nil)
            type = Spider.conf.get('shared_store.type').to_sym unless type
            type = :memory unless type
            case type
            when :memory
                return MemorySharedStore.new(config)
            when :file
                return FileSharedStore.new(config)
            end
        end
        
        def initialize(config={})
            @config = config
        end
        
        def [](key, &proc)
            raise NotImplementedError
        end
        
        def []=(key)
            raise NotImplementedError
        end
        
        def lock_all(&proc)
            raise NotImplementedError
        end
        
        
        
        
    end
    
end; end

require 'spiderfw/utils/shared_store/memory_shared_store'
require 'spiderfw/utils/shared_store/file_shared_store'
