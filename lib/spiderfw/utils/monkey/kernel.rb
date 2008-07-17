module Kernel
    
    def const_get_full(const)
        const.to_s.split("::").inject(Object) {|c1,c2| c1.const_get(c2)}
    end
    
end