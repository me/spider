module Spider; module ControllerMixins
    
    module StaticContent
        
        def self.included(klass)
            klass.route('pub/', :serve_static)
            klass.route('w/', :serve_widget_static)
            klass.no_layout('pub')
            klass.no_layout('serve_static')
        end
        
        def sanitize_path(path)
            return path.gsub('..', '')
        end
        
        def serve_static(path)
            path = sanitize_path(path)
            full_path = self.class.app.pub_path+'/'+path
            raise Spider::Controller::NotFound.new(path) unless File.exist?(full_path)
            output_static(full_path)
        end
        
        def serve_widget_static(path)
            path = sanitize_path(path)
            parts = path.split('/pub/', 2)
            raise Spider::Controller::NotFound.new(path) unless parts[1]
            full_path = self.class.app.widgets_path+'/'+parts[0]+'/pub/'+parts[1]
            raise Spider::Controller::NotFound.new(path) unless File.exist?(full_path)
            output_static(full_path)
        end
        
        def output_static(full_path)
            debug("Serving resource: #{full_path}")
            raise Spider::Controller::NotFound.new(full_path) unless File.exist?(full_path)
            f = File.open(full_path, 'r')
            while (block = f.read(1024)) do
                $out << block
            end
        end
        
    end
    
    
end; end