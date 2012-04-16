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
            $PUB_URL = Spider::HomeController.pub_url
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
            compress_assets = {:js => {}, :css => {}}
            seen = {}
            js_translations = {}
            use_cdn = Spider.conf.get('assets.use_cdn')
            cname = File.basename(@path, '.layout.shtml')
            cname = File.basename(cname, '.shtml')
            cname += "-#{@asset_set}" if @asset_set
            @cname = cname

            all_assets.each do |ass|
                seen_check = ass[:runtime] || ass[:src]
                next if ass[:src].blank? && !ass[:runtime]
                next if seen[seen_check]
                seen[seen_check] = true
                ass[:app] = Spider.home if ass[:app] == :home
                
                ass = compile_asset(ass)

                res = prepare_asset(ass, compress_assets, js_translations)
                assets[:css] += res[:css]
                assets[:js] += res[:js]

            end


            if @compile_less == false
                less = Spider::Template.get_named_asset('less')
                less.each do |ass|
                    res = prepare_asset(parse_asset(ass[:type], ass[:src], ass).first)
                    assets[:css] += res[:css]
                    assets[:js] += res[:js]
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
                    is_dyn = ass[:if_ie_lte] || ass[:media] || ass[:rel]
                    @template_assets[:css] << (is_dyn ? ass : ass[:src])
                end
            end
            
            @content[:yield_to] = @template
            @scene.assets = @template_assets
            @scene.extend(LayoutScene)
            if js_translations.empty?
                @scene.js_translations = ""
            else
                @scene.js_translations = "var translations = #{js_translations.to_json}"
            end
            
            @assets_prepared = true
        end

        def prepare_asset(ass, compress_assets={}, js_translations={})
            type = ass[:type].to_sym
            assets = {:css => [], :js => []}
            pub_dest = nil
            use_cdn = Spider.conf.get('assets.use_cdn')
                
            compress_config = case type
            when :js
                'javascript.compress'
            when :css
                'css.compress'
            end
            no_compress = @scene.__is_error_page || !Spider.conf.get(compress_config) || \
                            ass[:no_compress] || ass[:runtime] || ass[:if_ie_lte] || ass[:media] || (use_cdn && ass[:cdn])
            
            if no_compress
                if ass[:runtime]
                    assets[type] << {:src => Spider::Template.runtime_assets[ass[:runtime]].call(@request, @response, @scene)}
                else
                    assets[type] << ass
                end
            else
                unless pub_dest
                    pub_dest = self.class.compiled_folder_path
                    FileUtils.mkdir_p(pub_dest)
                end
                if comp = ass[:compressed_path] # Already compressed assets
                    name = File.basename(comp)
                    if ass[:compressed_rel_path] # Keeps the compressed files in a subdir
                        dir = File.dirname(ass[:compressed_rel_path])
                        if ass[:copy_dir] # Copies the source dir (which may contain resources used by the assets)
                            start = dir
                            if ass[:copy_dir].is_a?(Fixnum) # How many levels to go up
                                ass[:copy_dir].downto(0) do |i|
                                    start = File.dirname(start)
                                end
                            end
                            dst_dir = File.join(pub_dest, start)
                            unless File.dirname(start) == '.' || File.directory?(File.dirname(dst_dir))
                                FileUtils.mkdir_p(File.join(pub_dest, File.dirname(dst_dir)))
                            end
                            unless File.directory?(dst_dir)
                                FileUtils.cp_r(File.join(ass[:app].pub_path, start), dst_dir)
                            end
                        else
                            FileUtils.mkdir_p(File.join(pub_dest, dir))
                            FileUtils.cp(comp, File.join(pub_dest, dir)) unless File.exist?(File.join(pub_dest, dir))
                        end
                        src = dir+'/'+name
                    else
                        unless File.exist?(File.join(pub_dest, name))
                            FileUtils.cp(comp, pub_dest)
                        end
                        src = name
                    end
                    ass[:src] = Spider::HomeController.pub_url+'/'+COMPILED_FOLDER+'/'+src
                    assets[type] << ass
                else # needs compression
                    name = ass[:compress] || @cname
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
                if File.exists?(msg_path)
                    js_messages = JSON.parse(File.read(msg_path))
                    Spider::GetText.in_domain(ass[:app].short_name) do
                        js_messages.each{ |msg|
                            next if js_translations.key?(msg)
                            js_translations[msg] = _(msg) 
                        }
                    end
                else
                    Spider.logger.warn("Javascript Gettext file #{msg_path} not found")
                end
            end
            assets
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
            tpl_assets = @template.is_a?(Layout) ? @template.all_assets : @template.assets
            assets = tpl_assets + self.assets
            if @only_asset_profiles
                assets = assets.select{ |ass| ass[:profiles] && !(ass[:profiles] & @only_asset_profiles).empty? }
            end
            if @no_asset_profiles
                assets = assets.select{ |ass| !ass[:profiles] || (ass[:profiles] & @no_asset_profiles).empty? }
            end
            assets
        end
        
        COMPILED_FOLDER = '_c'

        def self.compiled_folder_path
             File.join(Spider::HomeController.pub_path, COMPILED_FOLDER)
        end
        
        def asset_gettext_messages_file(path)
            dir = File.dirname(path)
            name = File.basename(path, '.*')
            File.join(dir, "#{name}.i18n.json")
        end
        
        def compile_asset(ass)
            return ass unless ass[:src] && ass[:path]
            if ass[:type] == :css
                ext = File.extname(ass[:path])
                compile_exts = ['.scss', '.sass', '.less']

                if compile_exts.include?(ext)
                    ass_type = nil
                    if ext == '.less'
                        ass_type = :less
                        if @compile_less.nil?
                            @compile_less = false
                            if Spider.conf.get('css.compile_less')
                                begin
                                    require 'spiderfw/templates/resources/less'
                                    @compile_less = true
                                rescue LoadError
                                    Spider.logger.error("Unable to compile LESS. Please install less-js gem and a JS backend.")
                                end
                            end
                        end
                        unless @compile_less
                            ass[:rel] = 'stylesheet/less'
                            return ass
                        end
                    elsif ['.scss', '.sass'].include?(ext)
                        ass_type = :sass
                    end
                    dir = File.dirname(ass[:path])
                    base = File.basename(ass[:path], ext)
                    newname = "#{base}.css"
                    parts = dir.split(File::SEPARATOR)
                    if type_i = parts.index(ass_type.to_s)
                        parts[type_i] = File.join(ass[:type].to_s, ass_type.to_s)
                        destdir = parts.join(File::SEPARATOR) 
                    else
                        destdir = dir
                    end
                    FileUtils.mkdir_p(destdir)
                    dest = File.join(destdir, newname)
                    if Spider.conf.get('css.compile')
                        begin
                            compiler_class = if ass_type == :sass
                                require 'spiderfw/templates/resources/sass'
                                Spider::SassCompiler
                            elsif ass_type == :less
                                Spider::LessCompiler
                            end
                            compiler = compiler_class.new(ass[:app].pub_path)
                            compiler.compile(ass[:path], dest)
                        rescue Exception => exc
                            if ext == '.less'
                                msg = "Unable to compile LESS file #{ass[:path]}."
                                msg += "Please ensure you have a JS backend (see https://github.com/sstephenson/execjs)"
                            elsif ext == '.scss' || ext == '.sass'
                                msg = "Unable to compile SASS file #{ass[:path]}."
                                msg += "Please ensure that you have the 'sass' (and optionally 'compass') gems installed."
                            end
                            Spider.logger.error(msg)
                            if Spider.runmode == "production" && File.exist?(dest)
                                Spider.logger.error(exc)
                            else
                                raise
                            end
                        end
                    end
                    ass[:path] = dest
                    srcdir = File.dirname(ass[:src])
                    if destdir != dir
                        srcdir = srcdir.sub(ass_type.to_s, File.join(ass[:type].to_s, ass_type.to_s))
                    end
                    ass[:src] = File.join(srcdir, newname)
                    
                end
            end
            return ass
        end
        
        def compress_javascript(cpr)
            require 'yui/compressor'

            pub_dest = self.class.compiled_folder_path
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
                    currname = File.basename(f)
                    if currname =~ /(\d+)\.js$/
                        version = $1.to_i if $1.to_i > version
                        File.unlink(f)
                    end
                end
            end
            version += 1
            compiled_name = "#{name}.#{version}.js"
            combined = "#{pub_dest}/._#{compiled_name}"

            dest = "#{pub_dest}/#{compiled_name}"
            FileUtils.cp(tmp_combined, combined)
            File.unlink(tmp_combined)
            compressor = ::YUI::JavaScriptCompressor.new("charset" => "UTF-8")
            io = open(combined, 'r')
            cjs = compressor.compress(io)
            open(dest, 'w') do |f|
                f << cjs
            end
            return compiled_name
            
        end
        
        def compress_css(cpr)
            require 'yui/compressor'
            
            pub_dest = self.class.compiled_folder_path
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
                        if app.is_a?(Spider::Home)
                            app_relative_path = nil
                            app_path = app.path
                        else
                            app_relative_path = a[:app].relative_path
                            app_path = app.path
                        end
                    elsif path.index(Spider::SpiderController.pub_path) == 0
                        app_relative_path = 'spider'
                        app_path = Spider::SpiderController.pub_path
                    end
                    app_pathname = Pathname.new(app_path)

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
                        url, cb = url.split('?', 2)
                        path = ""
                        url_src = File.expand_path(File.join(src_dir, url))
                        src_pathname = Pathname.new(url_src)
                        src_rel = nil
                        begin
                            src_rel = src_pathname.relative_path_from(app_pathname)
                        rescue ArgumentError
                            raise "Can't combine CSS if paths go outside app: #{url} in #{path}"
                        end
                        
                        url_dest = File.join(pub_app, src_rel.to_s)
                        
                        FileUtils.mkdir_p(File.dirname(url_dest))
                        cachebuster = Spider.conf.get('css.cachebuster')
                        new_url = app_relative_path ? "#{app_relative_path}/#{src_rel}" : src_rel
                        if File.file?(url_src)
                            mtime = File.mtime(url_src).to_i
                            if cachebuster && File.exist?(url_dest) && mtime > File.mtime(url_dest).to_i
                                if cachebuster == :soft
                                    FileUtils.cp(url_src, url_dest)
                                    new_url += "?cb=#{mtime}"
                                elsif cachebuster == :hard || cachebuster == :hardcopy
                                    url_dir = File.dirname(url)
                                    url_ext = File.extname(url)
                                    url_basename = File.basename(url, url_ext)
                                    url_dest_dir = File.dirname(url_dest)
                                    cb_file_name = "#{url_basename}-cb#{mtime}#{url_ext}"
                                    new_url = "#{url_dir}/#{cb_file_name}"
                                    if cachebuster == :hard
                                        FileUtils.cp(url_src, url_dest)
                                    else
                                        FileUtils.cp(url_src, "#{url_dest_dir}/#{cb_file_name}")
                                    end
                                end
                            else
                                FileUtils.cp(url_src, url_dest)
                            end
                        else
                            Spider.logger.error("CSS referenced file not found: #{url_src}")
                        end
                        if cb
                            url += "?#{cb}"
                            new_url += "?#{cb}"
                        end
                        src.gsub!(/\([\s"']*#{Regexp.quote(url)}[\s"']*\)/m, "(#{new_url})")
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
            FileUtils.cp(tmp_combined, combined)
            File.unlink(tmp_combined)
            compressor = ::YUI::CssCompressor.new("charset" => "UTF-8")
            io = open(combined, 'r')
            cjs = compressor.compress(io)
            open(dest, 'w') do |f|
                f << cjs
            end
            return compiled_name
        end

        def self.clear_compiled_folder!
            FileUtils.rm_rf(Dir.glob(File.join(self.compiled_folder_path, '*')))
        end
        
    end
    
    module LayoutScene
        
        def output_meta(type=nil)
            type ||= :default
            case type
            when :default
                $out << "<link rel=\"index\" href=\"#{self.controller[:request_url]}\">"
            end
        end
        
        def output_assets(type=nil)
            types = type ? [type] : self.assets.keys
            if types.include?(:js)
                self.assets[:js].each do |ass|
                    ass = {:src => ass} if ass.is_a?(String)
                    $out << "<script type=\"text/javascript\" src=\"#{ass[:src]}\"></script>\n"
                end
                unless @not_first_js
                    $out << "<script type=\"text/javascript\">"
                    @not_first_js = true
                    $out << "window.SPIDER_BASE_URL = '#{self[:base_url]}'; "
                    $out << "if (window.Spider) Spider.baseUrl = window.SPIDER_BASE_URL;\n"
                    unless self[:js_translations].blank?
                        $out << self[:js_translations]+"\n"
                    end
                    $out << "</script>"
                end
            end
            if types.include?(:css)
                self.assets[:css].each do |ass|
                    ass = {:src => ass} if ass.is_a?(String)
                    rel = ass[:rel] || 'stylesheet'
                    link = "<link rel=\"#{rel}\" type=\"text/css\" href=\"#{ass[:src]}\""
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
