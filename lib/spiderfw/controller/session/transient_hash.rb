require 'spiderfw/controller/session/flash_hash'

module Spider
    
    class TransientHash < FlashHash
        
        def purge
            if (@parent_flash && @parent_flash_key && @parent_flash.accessed[@parent_flash_key])
                self.delete_if{ |k, v| !@accessed[k] && !@active[k] }
            end
            @sub_flashes.each{ |k, f| f.purge }
            @accessed = {}
            @active = {}
        end
        
    end
    
end