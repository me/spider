module Spider; module Model
    
    
    class ProxyModel < BaseModel
        
        
        def self.proxy(prefix, proxied)
            @prefix = prefix
            @proxied = proxied
            return self
        end
        
        def self.prefix
            @prefix
        end
        
        def self.proxied
            @proxied
        end
        
        def self.element(name, type, attributes={}, &proc)
            super
            define_method(name) do
                @proxied.send(name)
            end
            define_method("#{name}=") do |val|
                @proxied.send("#{name}=", val)
            end
        end
        
        def method_missing(method, *arguments)
            proxied.send("#{@prefix}#{method}", *arguments)
        end
        
    end
    
end; end