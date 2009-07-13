# Kernel monkey patch.

module Kernel
    
    # Utility method to get a full constant, like M::N::A
    #--
    # (from Merb)
    def const_get_full(const)
        const.to_s.split("::").inject(Object) {|c1,c2| c1.const_get(c2)}
    end
    
end