class Class
    
    def parent_module(n=1)
        return const_get_full(self.to_s.reverse.split('::', n+1)[n].reverse)
    end
    
    def has_ancestor?(ancestor)
        sup = superclass
        return true if (sup == ancestor || sup && sup.has_ancestor(ancestor))
        return false
    end
    
end
