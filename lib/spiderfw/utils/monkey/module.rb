class Module #:nodoc:

    # This is here just to be able to call this method on all constants
    def subclass_of?(klass)
        return false
    end
    
    def parent_module(n=1)
        return const_get_full(self.to_s.reverse.split('::', n+1)[n].reverse)
    end
    
end