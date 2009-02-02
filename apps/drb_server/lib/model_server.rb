require 'drb'

module SpiderApps; module DrbServer
    
    class ModelServer
        
        def initialize(uri=nil)
            @models = {}
            @uri = uri
        end
        
        def add(mod)
            if (mod.is_a?(Module) && mod.include?(Spider::App))
                mod.models.each { |m| @models[m] = true }
            elsif (mod.is_a?(Spider::Model::BaseModel))
                @models[mod] = true
            end
        end
        
        def start
            DRb.start_service @uri, self
            trap('TERM') { DRb.stop_service }
            trap('INT') { DRb.stop_service }
            Spider::Logger.debug("Model server listening on #{DRb.uri}")
            DRb.thread.join
        end
        
        def get(model_name, *args)
            model = const_get_full(model_name)
            return model.new(*args)
        end
        
        def method_missing(method, *args)
            model = const_get_full(args.shift)
            return model.send(method, *args)
        end
        
    end
    
    
end; end