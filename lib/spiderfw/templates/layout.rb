require 'spiderfw/content_utils'

module Spider
    
    class Layout < Template
#        allow_blocks :HTML, :Text, :Render, :Yield, :If, :TagIf, :Each, :Pass, :Widget
        attr_accessor :template
        
        def init(scene)
            super
            @template = @template.is_a?(Template) ? @template : Template.new(@template)
            @template.init(scene) unless @template.init_done?
            
        end
        
        def render(*args)
            prepare_assets unless @assets_prepared
            super
        end
        
        def prepare_assets
            @template_assets = { :css => [], :js => [] }
            seen = {}
            js = []
            css = []
            runtime = []
            all_assets.each do |res|
                next if seen[res[:src]]
                seen[res[:src]] = true
                @template_assets[res[:type].to_sym] ||= []
                @template_assets[res[:type].to_sym] << res[:src]
                if res[:runtime]
                    runtime << res
                else
                    js << res if Spider.conf.get('javascript.compress') && res[:type].to_sym == :js
                    css << res if Spider.conf.get('css.compress') && res[:type].to_sym == :css
                end
            end
            if Spider.conf.get('javascript.compress') && !@scene.__is_error_page
                compressed = compress_javascript(js)
                @template_assets[:js] = compressed.map{ |c|
                    Spider::HomeController.pub_url+'/'+COMPILED_FOLDER+'/'+c
                }
            end
            if Spider.conf.get('css.compress') && !@scene.__is_error_page
                combined = compress_css(css)
                @template_assets[:css] = combined.map{ |c|
                    Spider::HomeController.pub_url+'/'+COMPILED_FOLDER+'/'+c
                }
            end
            runtime.each do |rt|
                @template_assets[rt[:type]] << Spider::Template.runtime_assets[rt[:runtime]].call(@request, @response, @scene)
            end
            @content[:yield_to] = @template
            @scene.assets = @template_assets
            @assets_prepared = true
        end
        
        @@named_layouts = {}
        
        class << self
            
            def register_layout(name, file)
                @@named_layouts[name] = file
            end
            
            def named_layouts
                @@named_layouts
            end
            
        end
        
        def all_assets
            return @template.assets + self.assets
        end
        
        COMPILED_FOLDER = '_c'
        
        def compress_javascript(assets)
            require 'yui/compressor'
            res = []
            compress = {}
            compressed = []
            cname = File.basename(@path, '.layout.shtml')
            assets.each do |ass|
                if ass[:compressed]
                    compressed << ass[:compressed_path]
                else
                    name = ass[:compress] || cname
                    compress[name] ||= []
                    compress[name] << ass
                end
            end
            pub_dest = Spider::HomeController.pub_path+'/'+COMPILED_FOLDER
            FileUtils.mkdir_p(pub_dest)

            compress.each do |name, ass|

                already_compressed = Dir.glob(pub_dest+'/'+name+'.*.js')
                unless already_compressed.empty?
                    res << File.basename(already_compressed.first)
                    next
                end
                
                tmp_combined = Spider.paths[:tmp]+'/_'+name+'.js'
                File.open(tmp_combined, 'w') do |f|
                    ass.each do |a|
                        f.write IO.read(a[:path])+"\n"
                    end
                end
                version = 0
                curr = Dir.glob(pub_dest+"/._#{name}.*.js")
                unless curr.empty?
                    curr.each do |f|
                        name = File.basename(f)
                        if name =~ /(\d+)\.js$/
                            version = $1.to_i if $1.to_i > version
                            File.unlink(f)
                        end
                    end
                end
                version += 1
                compiled_name = "#{name}.#{version}.js"
                combined = "#{pub_dest}/._#{compiled_name}"

                dest = "#{pub_dest}/#{compiled_name}"
                File.cp(tmp_combined, combined)
                File.unlink(tmp_combined)
                compressor = YUI::JavaScriptCompressor.new("charset" => "UTF-8")
                io = open(combined, 'r')
                cjs = compressor.compress(io)
                open(dest, 'w') do |f|
                    f << cjs
                end
                res << compiled_name
            end
            
            compressed.uniq.each do |comp|
                name = File.basename(comp)
                unless File.exist?("#{pub_dest}/#{name}")
                    File.cp(comp, pub_dest)
                end
                res << name
            end
            res
        end
        
        def compress_css(assets)
            res = []
            combine = {}
            cname = File.basename(@path, '.layout.shtml')
            assets.each do |ass|
                name = ass[:combine] || cname
                combine[name] ||= []
                combine[name] << ass
            end
            pub_dest = Spider::HomeController.pub_path+'/'+COMPILED_FOLDER
            FileUtils.mkdir_p(pub_dest)
            combine.each do |name, ass|
                already_compressed = Dir.glob(pub_dest+'/'+name+'.*.css')
                unless already_compressed.empty?
                    res << File.basename(already_compressed.first)
                    next
                end
                tmp_combined = Spider.paths[:tmp]+'/_'+name+'.css'
                
                File.open(tmp_combined, 'w') do |f|
                    ass.each do |a|
                        path = a[:path]
                        src_dir = File.dirname(path)
                        app = a[:app]
                        if app
                            app_relative_path = a[:app].relative_path
                            app_path = app.path
                        elsif path.index(Spider::SpiderController.pub_path) == 0
                            app_relative_path = 'spider'
                            app_path = Spider::SpiderController.pub_path
                        end

                        pub_app = "#{pub_dest}/#{app_relative_path}"
                        FileUtils.mkdir_p(pub_app)
                        src_files = Spider::ContentUtils.resolve_css_includes(path)
                        src = ""
                        src_files.each do |src_file|
                            src += IO.read(src_file)+"\n"
                        end
                        src.gsub!(/^\s*@import(?:\surl\(|\s)(['"]?)([^\?'"\)\s]+)(\?(?:[^'"\)]*))?\1\)?(?:[^?;]*);?/i, "")

                        src.scan(/url\([\s"']*([^\)"'\s]*)[\s"']*\)/m).uniq.collect do |url|
                            url = url.first
                            next if url =~ %r{^/} || url =~ %r{^[a-z]+://}
                            path = ""
                            url_dest = File.expand_path(File.join(pub_app, url))
                            url_src = File.expand_path(File.join(src_dir, url))
                            unless url_src.index(app_path) == 0
                                raise "Can't combine CSS if paths go outside app: #{url} in #{path}"
                            end
                            FileUtils.mkdir_p(File.dirname(url_dest))
                            cachebuster = Spider.conf.get('css.cachebuster')
                            new_url = "#{app_relative_path}/#{url}"
                            if File.exist?(url_src)
                                mtime = File.mtime(url_src).to_i
                                if cachebuster && File.exist?(url_dest) && mtime > File.mtime(url_dest).to_i
                                    if cachebuster == :soft
                                        File.cp(url_src, url_dest)
                                        new_url += "?cb=#{mtime}"
                                    elsif cachebuster == :hard || cachebuster == :hardcopy
                                        url_dir = File.dirname(url)
                                        url_ext = File.extname(url)
                                        url_basename = File.basename(url, url_ext)
                                        url_dest_dir = File.dirname(url_dest)
                                        cb_file_name = "#{url_basename}-cb#{mtime}#{url_ext}"
                                        new_url = "#{url_dir}/#{cb_file_name}"
                                        if cachebuster == :hard
                                            File.cp(url_src, url_dest)
                                        else
                                            File.cp(url_src, "#{url_dest_dir}/#{cb_file_name}")
                                        end
                                    end
                                else
                                    File.cp(url_src, url_dest)
                                end
                            else
                                Spider.logger.error("CSS referenced file not found: #{url_src}")
                            end
                            src.gsub!(/\([\s"']*#{url}[\s"']*\)/m, "(#{new_url})")
                        end
                        f.write(src+"\n") 
                    end
                end
                
                version = 0
                curr = Dir.glob(pub_dest+"/._#{name}.*.css")                
                unless curr.empty?
                    curr.each do |f|
                        name = File.basename(f)
                        if name =~ /(\d+)\.js$/
                            version = $1.to_i if $1.to_i > version
                            File.unlink(f)
                        end
                    end
                end
                version += 1
                compiled_name = "#{name}.#{version}.css"
                combined = "#{pub_dest}/._#{compiled_name}"
                
                dest = "#{pub_dest}/#{compiled_name}"
                File.cp(tmp_combined, combined)
                File.unlink(tmp_combined)
                compressor = YUI::CssCompressor.new("charset" => "UTF-8")
                io = open(combined, 'r')
                cjs = compressor.compress(io)
                open(dest, 'w') do |f|
                    f << cjs
                end
                res << compiled_name
            end
            res
        end
        
    end
    
end