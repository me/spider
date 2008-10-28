class Class
    
    def parent_module(n=1)
        return const_get_full(self.to_s.reverse.split('::', n+1)[n].reverse)
    end
    
    def subclass_of?(klass)
        testklass = self
        testklass = testklass.superclass while (testklass != nil && testklass != klass)
        return true if testklass == klass
        return false
    end
    
    
end
