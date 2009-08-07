require 'webrick/httputils'
require 'mime/types'

module Spider; module ControllerMixins
    
    module StaticContent
        
        def self.included(klass)
            klass.extend(ClassMethods)
            klass.route('public/', :serve_static)
            klass.route('w/', :serve_widget_static)
            if (klass < Visual)
                klass.no_layout('public')
                klass.no_layout('serve_static')
            end
        end
        
        module ClassMethods
            def pub_url
                self.app.pub_url
            end
        end
        
        def sanitize_path(path)
            return path.gsub('..', '')
        end
        
        def serve_static(path=nil)
            raise Spider::Controller::NotFound.new(path) unless path
            path = sanitize_path(path)
            full_path = self.class.app.pub_path+'/'+path
            raise Spider::Controller::NotFound.new(path) unless File.exist?(full_path)
            output_static(full_path)
        end
        
        def serve_widget_static(path)
            path = sanitize_path(path)
            parts = path.split('/public/', 2)
            raise Spider::Controller::NotFound.new(path) unless parts[1]
            full_path = self.class.app.widgets_path+'/'+parts[0]+'/public/'+parts[1]
            raise Spider::Controller::NotFound.new(path) unless File.exist?(full_path)
            output_static(full_path)
        end
        
        def output_static(full_path)
            debug("Serving resource: #{full_path}")
            raise Spider::Controller::NotFound.new(full_path) unless File.exist?(full_path)
            stat = File.lstat(full_path)
            ct = File.directory?(full_path) ? "httpd/unix-directory" : WEBrick::HTTPUtils::mime_type(full_path, ::MIME::Types)
            @response.headers['Content-Type'] = ct
            @response.headers['Content-Length'] = stat.size
            @response.headers['Last-Modified'] = stat.mtime.httpdate
            f = File.open(full_path, 'r')
            while (block = f.read(1024)) do
                $out << block
            end
        end
        
    end
    
    
end; end