module Spider; module CASServer
    
    module Consumable
        def consume!
            self.consumed = DateTime.now
            self.save
        end
    end
    
end; end