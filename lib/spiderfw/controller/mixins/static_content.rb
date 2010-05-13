require 'spiderfw/controller/mixins/http_mixin'
require 'webrick/httputils'
require 'mime/types'

module Spider; module ControllerMixins
    
    module StaticContent
        include Spider::ControllerMixins::HTTPMixin
        
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
            
            def output_format?(method, format)
                return true if method == :serve_static
                return super
            end
            
            def pub_url
                self.app.pub_url
            end
            
            def pub_path
                self.app.pub_path
            end
            
        end
        
        def pub_path
            self.class.pub_path
        end
        
        def pub_url
            self.class.pub_url
        end
        
        def sanitize_path(path)
            return path.gsub('..', '')
        end
        
        def serve_static(path=nil)
            path += ".#{@request.format}" if @request.format
            raise Spider::Controller::NotFound.new(path) unless path
            path = sanitize_path(path)
            mode = Spider.conf.get('static_content.mode')
            if mode == 'publish' && self.class != Spider::HomeController
                url = self.pub_url
                url += "/"+path
                return redirect(url)
            end
            full_path = pub_path+'/'+path
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
            debug("Serving asset: #{full_path}")
            mode = Spider.conf.get('static_content.mode')
            raise Spider::Controller::NotFound.new(full_path) unless File.exist?(full_path)
            stat = File.lstat(full_path)
            if File.directory?(full_path)
                ct = "httpd/unix-directory"
            else
                ct = MIME::Types.type_for(full_path)
                ct = ct.to_s if ct
                ct ||= "application/octet-stream"
            end
            @response.headers['Content-Type'] = ct
            @response.headers['Content-Length'] = stat.size
            @response.headers['Last-Modified'] = stat.mtime.httpdate
            
            if mode == 'x-sendfile'
                @response.headers['X-Sendfile'] = full_path
            elsif mode == 'x-accel-redirect'
                @response.headers['X-Accel-Redirect'] = full_path
            else
                f = File.open(full_path, 'r')
                while (block = f.read(1024)) do
                    $out << block
                end
            end
        end
        
        def prepare_scene(scene)
            scene = super
            scene.controller[:pub_url] = pub_url
            return scene
        end
        
    end
    
    
end; end