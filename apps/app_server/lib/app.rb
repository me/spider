module Spider; module AppServer
    
    class App
        attr_reader :path
        attr_accessor :spec
        attr_reader :last_modified
        
        def initialize(path)
            @path = path
        end
        
        def method_missing(name, *args)
            @spec.send(name, *args) if @spec.respond_to?(name)
        end
        
        def to_json(options=nil)
            @spec.to_json
        end
        
        
    end
    
end; end
