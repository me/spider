require 'spiderfw/controller/mixins/http_mixin'
require 'webrick/httputils'
require 'mime/types'

module Spider; module ControllerMixins
    
    module StaticContent
        include Spider::ControllerMixin
        include Spider::ControllerMixins::HTTPMixin
        
        def self.included(klass)
            super
            @static_content_route ||= 'public/'
            klass.controller_actions(:serve_static)
            klass.route(@static_content_route, :serve_static, :do => lambda{ @serving_static = true })
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
            output_static(full_path)
        end
        
        def output_static(full_path, file_name=nil)
            file_name ||= File.basename(full_path)
            @request.misc[:is_static] = true
            debug("Serving asset: #{full_path}")
            begin
                while File.symlink?(full_path)
                    full_path = File.readlink(full_path)
                end
            rescue NotImplemented
            end
            mode = Spider.conf.get('static_content.mode')
            raise Spider::Controller::NotFound.new(full_path) unless File.exist?(full_path)
            stat = File.lstat(full_path)
            mtime = stat.mtime
            now = Time.now
            if @request.env['HTTP_IF_MODIFIED_SINCE'] && !@request.cache_control[:no_cache]
                if_modified = nil
                begin
                  if_modified = Time.httpdate(@request.env['HTTP_IF_MODIFIED_SINCE'])
                rescue ArgumentError # Passenger with IE6 has this header wrong
                end
                max_age = nil
                fresh = true
                if fresh && if_modified && mtime <= if_modified
                    debug("Not modified since #{if_modified}: #{full_path}")
                    #@response.status = Spider::HTTP::NOT_MODIFIED
                    @response.headers.delete("Content-Type")
                    @response.headers['Date'] = mtime.httpdate
                    @response.no_cookies
                    raise HTTPStatus.new(Spider::HTTP::NOT_MODIFIED) 
                    return
                end
            end
            if File.directory?(full_path)
                ct = "httpd/unix-directory"
            else
                ct = MIME::Types.type_for(file_name)
                ct = ct.first if ct.is_a?(Array)
                ct = ct.to_s if ct
                ct ||= "application/octet-stream"
            end
            @response.content_type = ct
            @response.content_length = stat.size
            @response.headers['Last-Modified'] = mtime.httpdate
            
            if mode == 'x-sendfile'
                @response.headers['X-Sendfile'] = full_path
            elsif mode == 'x-accel-redirect'
                @response.headers['X-Accel-Redirect'] = full_path
            else
                f = File.open(full_path, 'rb')
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
        
        def serving_static?(action=nil)
            return @serving_static if @serving_static || !action
            n = dispatch_next(action)
            n && n.action == "serve_static"
        end
        
    end
    
    
end; end