module Spider
    
    class FlashHash < Hash
        attr_accessor :parent_flash, :parent_flash_key
        attr_reader :accessed, :active
        
        def initialize
            super
            @sub_flashes = {}
            @parent_flash = nil
            @parent_flash_key = nil
            reset
        end
        
        def reset
            @active = {}
            @accessed = {}
            @sub_flashes.each{ |k, f| f.reset }
        end
        
        def [](key)
            @accessed[key] = true
            super
        end
        
        def []=(key, val)
            super
            active(key)
            if (val.is_a?(FlashHash))
                val.parent_flash = self
                val.parent_flash_key = key
                @sub_flashes[key] = val
            end
        end
        
        def active(key)
            @active[key] = true
            if (@parent_flash)
                @parent_flash.active(@parent_flash_key)
            end
        end
        
        def delete(key)
            super
            @sub_flashes.delete(key)
        end
        
        def purge
            self.delete_if{ |k, v| @accessed[k] && !@active[k] }
            @sub_flashes.each{ |k, f| f.purge }
        end
        
    end
    
    
end