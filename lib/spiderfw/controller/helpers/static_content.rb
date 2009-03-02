module Spider; module Helpers
    
    module StaticContent
        
        def self.included(klass)
            Spider::Logger.debug("STATIC CONTENT included in #{klass}")
            klass.route('pub/', :serve_static)
            klass.no_layout('pub')
            klass.no_layout('serve_static')
        end
        
        def serve_static(path)
            full_path = self.class.app.pub_path+'/'+path
            debug("Serving resource: #{full_path}")
            raise Spider::Controller::NotFound.new(path) unless File.exist?(full_path)
            f = File.open(full_path, 'r')
            while (block = f.read(1024)) do
                print block
            end
        end
        
    end
    
    
end; end