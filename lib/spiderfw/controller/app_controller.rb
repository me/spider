module Spider
    
    class AppController < Controller
        include Visual
        
        no_layout 'serve_resource'
        
        def initialize(request, response, scene=nil)
            route 'pub/', :serve_resource
            super
        end
        
        
        def serve_resource(path)
            full_path = self.class.app.pub_path+'/'+path
            debug("Serving resource: #{full_path}")
            raise NotFound.new(path) unless File.exist?(full_path)
            f = File.open(full_path, 'r')
            while (block = f.read(1024)) do
                print block
            end
        end
        
    end
    
end