class Class
    
    def parent_module(n=1)
        return const_get_full(self.to_s.reverse.split('::', n+1)[n].reverse)
    end
    
    def subclass_of?(klass)
        self.ancestors.include?(klass)
    end
    
end
