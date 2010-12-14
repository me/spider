require 'spiderfw/content_utils'

module Spider
    
    class Layout < Template
#        allow_blocks :HTML, :Text, :Render, :Yield, :If, :TagIf, :Each, :Pass, :Widget
        attr_accessor :template
        attr_accessor :asset_set
        
        def init(scene)
            super
            @template = @template.is_a?(Template) ? @template : Template.new(@template)
            @template.init(scene) unless @template.init_done?
            
        end
        
        def render(*args)
            prepare_assets unless @assets_prepared
            super
        end
        
        def only_asset_profiles(*profiles)
            @only_asset_profiles = profiles
        end
        
        def no_asset_profiles(*profiles)
            @no_asset_profiles = profiles
        end
        
        def prepare_assets
            @template_assets = { :css => [], :js => [] }
            assets = {:css => [], :js => []}
            seen = {}
            js_messages = []
            use_cdn = Spider.conf.get('assets.use_cdn')
            compress_assets = {:js => {}, :css => {}}
            cname = File.basename(@path, '.layout.shtml')
            cname = File.basename(cname, '.shtml')
            cname += "-#{@asset_set}" if @asset_set
            pub_dest = nil
            all_assets.each do |ass|
                seen_check = ass[:runtime] || ass[:src]
                next if !ass[:src] || ass[:src].empty?
                next if seen[seen_check]
                seen[seen_check] = true
                type = ass[:type].to_sym
                compress_config = case type
                when :js
                    'javascript.compress'
                when :css
                    'css.compress'
                end
                no_compress = @scene.__is_error_page || !Spider.conf.get(compress_config) || \
                                ass[:runtime] || ass[:if_ie_lte] || ass[:media] || (use_cdn && ass[:cdn])
                
                if no_compress
                    if ass[:runtime]
                        assets[type] << Spider::Template.runtime_assets[ass[:runtime]].call(@request, @response, @scene)
                    else
                        assets[type] << ass
                    end
                else
                    unless pub_dest
                        pub_dest = Spider::HomeController.pub_path+'/'+COMPILED_FOLDER
                        FileUtils.mkdir_p(pub_dest)
                    end
                    if comp = ass[:compressed_path]
                        name = File.basename(comp)
                        unless File.exist?(File.join(pub_dest, name))
                            File.cp(comp, pub_dest)
                        end
                        ass[:src] = Spider::HomeController.pub_url+'/'+COMPILED_FOLDER+'/'+name
                        assets[type] << ass
                    else
                        name = ass[:compress] || cname
                        unless compress_assets[type][name]
                            cpr = {:name => name, :assets => [], :cpr => true}
                            assets[type] << cpr
                            compress_assets[type][name] = cpr
                        end
                        compress_assets[type][name][:assets] << ass
                    end
                end
                if ass[:gettext] && type == :js
                    msg_path = asset_gettext_messages_file(ass[:path])
                    js_messages += JSON.parse(File.read(msg_path))
                end
            end
            assets[:js].each do |ass|
                if ass[:cpr]
                    compressed = compress_javascript(ass)
                    @template_assets[:js] << Spider::HomeController.pub_url+'/'+COMPILED_FOLDER+'/'+compressed
                else
                    ass[:src] = ass[:cdn] if ass[:cdn] && use_cdn
                    @template_assets[:js] << ass[:src]
                end
            end
            assets[:css].each do |ass|
                if ass[:cpr]
                    compressed = compress_css(ass)
                    @template_assets[:css] << Spider::HomeController.pub_url+'/'+COMPILED_FOLDER+'/'+compressed
                else
                    ass[:src] = ass[:cdn] if ass[:cdn] && use_cdn
                    is_dyn = ass[:if_ie_lte] || ass[:media]
                    @template_assets[:css] << (is_dyn ? ass : ass[:src])
                end
            end
            
            @content[:yield_to] = @template
            @scene.assets = @template_assets
            @scene.extend(LayoutScene)
            if js_messages.empty?
                @scene.js_translations = ""
            else
                translations = {}
                js_messages.each{ |msg| translations[msg] = _(msg) }
                @scene.js_translations = "var translations = #{translations.to_json}"
            end
            
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
            assets = @template.assets + self.assets
            if @only_asset_profiles
                assets = assets.select{ |ass| ass[:profiles] && !(ass[:profiles] & @only_asset_profiles).empty? }
            end
            if @no_asset_profiles
                assets = assets.select{ |ass| !ass[:profiles] || (ass[:profiles] & @no_asset_profiles).empty? }
            end
            assets
        end
        
        COMPILED_FOLDER = '_c'
        
        def asset_gettext_messages_file(path)
            dir = File.dirname(path)
            name = File.basename(path, '.*')
            File.join(dir, "#{name}.i18n.json")
        end
        
        def compress_javascript(cpr)
            require 'yui/compressor'

            pub_dest = Spider::HomeController.pub_path+'/'+COMPILED_FOLDER
            name = cpr[:name]
            
            already_compressed = Dir.glob(pub_dest+'/'+name+'.*.js')
            unless already_compressed.empty?
                return File.basename(already_compressed.first)
            end
            
            tmp_combined = Spider.paths[:tmp]+'/_'+name+'.js'
            File.open(tmp_combined, 'w') do |f|
                cpr[:assets].each.each do |a|
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
            return compiled_name
            
        end
        
        def compress_css(cpr)
            
            pub_dest = Spider::HomeController.pub_path+'/'+COMPILED_FOLDER
            name = cpr[:name]
            
            already_compressed = Dir.glob(pub_dest+'/'+name+'.*.css')
            unless already_compressed.empty?
                return File.basename(already_compressed.first)
            end
            
            tmp_combined = Spider.paths[:tmp]+'/_'+name+'.css'
                
            File.open(tmp_combined, 'w') do |f|
                cpr[:assets].each do |a|
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
                    currname = File.basename(f)
                    if currname =~ /(\d+)\.js$/
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
            return compiled_name
        end
        
    end
    
    module LayoutScene
        
        def output_assets(type=nil)
            types = type ? [type] : self.assets.keys
            use_cdn = Spider.conf.get('assets.use_cdn')
            if types.include?(:js)
                debugger
                self.assets[:js].each do |ass|
                    ass = {:src => ass} if ass.is_a?(String)
                    $out << "<script type=\"text/javascript\" src=\"#{ass[:src]}\"></script>\n"
                end
            end
            if types.include?(:css)
                self.assets[:css].each do |ass|
                    ass = {:src => ass} if ass.is_a?(String)
                    link = "<link rel=\"stylesheet\" type=\"text/css\" href=\"#{ass[:src]}\""
                    link += " media=\"#{ass[:media]}\"" if ass[:media]
                    link += ">\n"
                    if ass[:if_ie_lte]
                        link = "<!--[if lte IE #{ass[:if_ie_lte]}]>\n#{link}<![endif]-->\n"
                    end
                    $out << link
                end
            end
        end
        
    end
    
    
end
