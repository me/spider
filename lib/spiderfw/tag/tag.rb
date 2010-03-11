require 'erb'

module Spider
    
    class Tag
        
        class << self
            attr_accessor :path
            
            def new_class(path)
                k = Class.new(self)
                k.path = path
                return k
            end
        end
        
        def initialize(el)
            @attributes = el.attributes.to_hash
            @content = el.innerHTML
        end
        
        def render
            return ERB.new(IO.read(self.class.path)).result(binding)
        end
        
    end
    
end