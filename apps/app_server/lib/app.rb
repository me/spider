module Spider; module AppServer
    
    class App
        attr_accessor :spec
        attr_reader :last_modified
        
        def initialize
        end
        
        def method_missing(name, *args)
            @spec.send(name, *args) if @spec.respond_to?(name)
        end
        
        def to_json
            @spec.to_json
        end
        
        
    end
    
end; end