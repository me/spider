require 'hpricot'
require 'spiderfw/patches/hpricot'
require 'spiderfw/templates/template_blocks'
require 'spiderfw/cache/template_cache'
begin
    require 'less'
    require 'spiderfw/templates/assets/less'
rescue LoadError
end

Spider.register_resource_type(:css, :extensions => ['css'], :path => 'public')
Spider.register_resource_type(:js, :extensions => ['js'], :path => 'public')


module Spider
    
    module TemplateAssets; end
    
    # This class manages SHTML templates.
    
    class Template
        include Logger
        
        attr_accessor :_action, :_action_to, :_widget_action
        attr_accessor :widgets, :compiled, :id_path
        attr_accessor :request, :response, :owner, :owner_class, :definer_class
        attr_accessor :mode # :widget, ...
        attr_accessor :assets
        attr_accessor :runtime_overrides
        attr_reader :overrides, :path, :subtemplates, :widgets, :content
        attr_accessor :asset_profiles
        attr_accessor :subtemplate_of
        
        @@registered = {}
        @@widget_plugins = {}
        @@namespaces = {}
        @@overrides = ['content', 'override', 'override-content', 'override-attr', 'append-attr',
                        'append', 'prepend', 'delete', 'before', 'after']
                        
        @@asset_types = {
            :css => {},
            :js => {},
            :less => {:processor => :Less}
        }
        
        class << self
            
            def cache_path
                File.join(Spider.paths[:var], 'cache', 'templates')
            end
            # Returns the class TemplateCache instance
            def cache
                @@cache ||= TemplateCache.new(self.cache_path)
            end
            
            # Sets allowed blocks
            def allow_blocks(*tags) # :nodoc:
                @allowed_blocks = tags
            end

            # Returns allowed blocks
            def allowed_blocks # :nodoc:
                @allowed_blocks
            end
            
            def asset_types # :nodoc:
                @@asset_types
            end

            # Returns a new instance, loading path.
            def load(path)
                raise RuntimeError, "Template #{path} does not exist" unless File.exist?(path)
                template = self.new(path)
                template.load(path)
                return template
            end
            
            # Registers a tag
            def register(tag, symbol_or_class)
                @@registered[tag] = symbol_or_class
            end
                        
            # Returns an hash of registered tags.
            def registered
                @@registered
            end
            
            # Checks if the tag is registered.
            def registered?(tag)
                return true if @@registered[tag]
                ns, tag = tag.split(':')
                if tag # that is, if there is a ns
                    return false unless @@namespaces[ns]
                    return @@namespaces[ns].has_tag?(tag)
                end
                return false
            end
            
            # Registers a namespace (mod should probably be a Spider::App, and must respond to 
            # get_tag and has_tag? methods).
            def register_namespace(ns, mod)
                @@namespaces[ns] = mod
            end
            
            # Returns the Class registered for the given tag.
            def get_registered_class(name)
                if @@registered[name]
                    klass = @@registered[name]
                else
                    ns, tag = name.split(':')
                    klass = @@namespaces[ns].get_tag(tag) if tag && @@namespaces[ns]
                end
                return nil unless klass
                klass = const_get_full(klass) if klass.is_a?(Symbol)
                return klass
            end
            
            # Returns the view path (see #Spider::find_asset)
            def real_path(path, cur_path=nil, owner_classes=nil, search_paths=[])
                Spider.find_resource_path(:views, path, cur_path, owner_classes, search_paths)
            end
            
            def find_resource(path, cur_path=nil, owner_classes=nil, search_paths=[])
                Spider.find_resource(:views, path, cur_path, owner_classes, search_paths)
            end
            
            def define_named_asset(name, assets, options={})
                @named_assets ||= {}
                @named_assets[name] = { :assets => assets, :options => options }
            end
            
            def named_assets
                @named_assets || {}
            end
            
            def define_runtime_asset(name, &proc)
                @runtime_assets ||= {}
                @runtime_assets[name] = proc
            end
            
            def runtime_assets
                @runtime_assets || {}
            end
            
            def get_named_asset(name)
                res = []
                ass = self.named_assets[name] 
                raise "Named asset #{name} is not defined" unless ass
                deps = ass[:options][:depends] if ass[:options]
                deps = [deps] if deps && !deps.is_a?(Array)
                if deps
                    deps.each do |dep|
                        res += get_named_asset(dep)
                    end
                end
                ass[:assets].each do |a|
                    attributes = a[3] || {}
                    res << {:type => a[0], :src => a[1], :app => a[2]}.merge(attributes)
                end
                res
            end
            
            # An array of possible override tags.
            # Overrides may be used when placing a widget in a template, or when including another template.
            # All except tpl:content may have the _search_ attribute, that is a CSS or XPath expression specifing
            # the nodes to override. If the _search_ attribute is missing, the override will be applied to the
            # root node.
            #
            # Example:
            #   <div class="my_widget_template">
            #     <div class="a">aaa</div>
            #     <div class="b">bbb</div>
            #   </div>
            #   
            # and
            #
            #   <div class="my_template">
            #     <my:widget id="my_widget_instance">
            #        <tpl:override search=".b">bbb and a c</tpl:override>
            #     </my:widget>
            #   </div>
            #
            # will result in the widget using the template
            #   <div class="my_widget_template">
            #     <div class="a">aaa</div>
            #     <div class="b">bbb and c</div>
            #   </div>
            # 
            # The tags are in the _tpl_ namespace.
            # *<tpl:content [name='...'] />*     overrides the content of the found element.
            #                                    If name is given, will override the named content found in the
            #                                    original template.
            # *<tpl:override />*        replaces the found nodes with given content
            # *<tpl:override-attr name='...' value='...' />*     overrides the given attribute
            # *<tpl:append />*  appends the given content to the container
            # *<tpl:prepend />* prepends the given content
            # *<tpl:delete />* removes the found nodes
            # *<tpl:before />* inserts the given content before the found nodes
            # *<tpl:after />* inserts the given content after the found nodes
            # *<tpl:content name="content-name" />* replaces a <tpl:placeholder> with the same name
            def override_tags
                @@overrides
            end
            
            def parse_asset_element(el)
                h = {}
                el.attributes.to_hash.each do |k, v|
                    h[k.to_sym] = v
                end
                h
                # end
                # {
                #     :type => el.get_attribute('type'),
                #     :src => el.get_attribute('src'),
                #     :attributes => el.attributes.to_hash
                # }
            end
            
        end
        
        # Returns the class override_tags
        def override_tags
            @@overrides
        end
        
        def initialize(path=nil)
            @path = path
            @widgets = {}
            @subtemplates = {}
            @widget_templates = []
            @subtemplate_owners = {}
            @id_path = []
            @assets = []
            @content = {}
            @dependencies = []
            @overrides = []
            @widgets_overrides = {}
            @widget_procs = {}
            @runtime_overrides = []
        end
        
        # Sets the scene.
        def bind(scene)
            @scene = scene
            return self
        end
        
        
        # Loads the compiled template (from cache if available).
        def load(path=nil)
            @path = real_path(path) if path
            @path = File.expand_path(@path)
#            debug("TEMPLATE LOADING #{@path}")
            cache_path = @path.sub(Spider.paths[:root], 'ROOT').sub(Spider.paths[:spider], 'SPIDER')
            unless @runtime_overrides.empty?
                cache_path_dir = File.dirname(cache_path)
                cache_path_file = File.basename(cache_path, '.shtml')
                suffix = @runtime_overrides.map{ |ro| ro[0].to_s }.sort.join('+')
                cache_path = cache_path_dir+'/'+cache_path_file+'+'+suffix+'.shtml'
                @runtime_overrides.each do |ro|
                    @overrides += ro[1]
                    @dependencies << ro[2]
                end
            end
            @compiled = self.class.cache.fetch(cache_path) do
                begin
                    compile(:mode => @mode)
                rescue Exception
                    Spider.logger.error("Failed compilation of template #{@path}:")
                    raise
                end
            end
        end
        
        # Recompiles the template; returns a CompiledTemplate.
        def compile(options={})
            compiled = CompiledTemplate.new
            compiled.source_path = @path
            doc = open(@path){ |f| Hpricot.XML(f) }
            root = get_el(doc)
            process_tags(root)
            apply_overrides(root)
            root.search('tpl:placeholder').remove # remove empty placeholders
            owner_class = @owner ? @owner.class : @owner_class
            @assets += owner_class.assets if owner_class
            res =  root.children ? root.children_of_type('tpl:asset') : []
            res_init = ""
            res.each do |r|
                @assets << Spider::Template.parse_asset_element(r)
                r.set_attribute('class', 'to_delete')
            end
            new_assets = []
            @assets.each do |ass|
                a = parse_asset(ass[:type], ass[:src], ass)
                new_assets += a
            end
            @assets = new_assets
            root.search('.to_delete').remove
            root.search('tpl:assets').each do |ass|
                if wattr = ass.get_attribute('widgets')
                    wattr.split(/,\s*/).each do |w|
                        w_templates = nil
                        if w =~ /(\.+)\((.+)\)/
                            w = $1
                            w_templates = $2.split('|')
                        end
                        klass = Spider::Template.get_registered_class(w)
                        unless klass
                            Spider.logger.warn("tpl:assets requested non existent widget #{w}")
                            next
                        end
                        w_templates ||= [klass.default_template]
                        w_templates.each do |wt| 
                            t = klass.load_template(wt)
                            add_widget_template(t, klass)
                        end
                    end
                elsif sattr = ass.get_attribute('src')
                    sattr.split(/,\s*/).each do |s|
                        s_template = Spider::Template.new(s)
                        s_template.owner = @owner
                        s_template.definer_class = @definer_class
                        s_template.load(s)
                        @assets = s_template.assets + @assets
                    end
                end
            end
            root.search('tpl:assets').remove
            root_block = TemplateBlocks.parse_element(root, self.class.allowed_blocks, self)
            if doc.children && doc.children[0].is_a?(Hpricot::DocType)
                root_block.doctype = doc.children[0]
                options[:doctype] = DocType.new(root_block.doctype)
            else
                options[:doctype] ||= DocType.new(Spider.conf.get('template.default_doctype'))
            end
            options[:root] = true
            options[:owner] = @owner
            options[:owner_class] = @owner_class || @owner.class
            options[:template_path] = @path
            options[:template] = self
            compiled.block = root_block.compile(options)
            subtemplates.each do |id, sub|
                sub.owner_class = @subtemplate_owners[id]
                sub.subtemplate_of = options[:owner_class]
                compiled.subtemplates[id] = sub.compile(options.merge({:mode => :widget})) # FIXME! :mode => :widget is wrong, it's just a quick kludge
                @assets += compiled.subtemplates[id].assets
            end
            @widget_templates.each do |wt|
                wt.mode = :widget
                wt.load
                # sub_c = sub.compile(options.merge({:mode => :widget}))
                @assets = wt.compiled.assets + @assets
            end
            
            seen = {}
            # @assets.each_index do |i|
            #     ass = @assets[i]
            #     if ass[:name]
            # end
            @assets.each do |ass|
                ass[:profiles] = ((ass[:profiles] || []) + @asset_profiles).uniq if @asset_profiles
                next if seen[ass.inspect]
                res_init += "@assets << #{ass.inspect}\n"
                # res_init += "@assets << {
                #     :type => :#{ass[:type]}, 
                #     :src => '#{ass[:src]}',
                #     :path => '#{ass[:path]}',
                #     :if => '#{ass[:if]}'"
                # res_init += ",\n :compiled => '#{ass[:compressed]}'" if ass[:compressed]
                # res_init += "}\n"
                seen[ass.inspect] = true
            end
            compiled.block.init_code = res_init + compiled.block.init_code
            compiled.devel_info["source.xml"] = root.to_html
            compiled.assets = (@assets + assets).uniq
            return compiled
        end
        
        # Processes an asset. Returns an hash with :type, :src, :path.
        def parse_asset(type, src, attributes={})
            # FIXME: use Spider.find_asset ?
            type = type.to_sym if type
            ass = {:type => type}
            if attributes[:name]
                named = Spider::Template.get_named_asset(attributes[:name])
                raise "Can't find named asset #{attributes[:name]}" unless named
                if attributes[:profiles]
                    named.each{ |nmdass| nmdass[:profiles] = attributes[:profiles] }
                end
                return named.map{ |nmdass| 
                    parse_asset(nmdass[:type], nmdass[:src], nmdass)
                }.flatten
            end
            if attributes[:profiles]
                ass[:profiles] = attributes[:profiles].split(/,\s*/).map{ |p| p.to_sym }
            end
            if attributes[:app] == :runtime
                ass[:runtime] = src
                return [ass]
            end
            if attributes[:app]
                asset_owner = attributes[:app]
                asset_owner = Spider.apps_by_path[asset_owner] unless asset_owner.is_a?(Module)
            elsif attributes[:home]
                asset_owner = Spider.home
            else
                asset_owner = (@owner ? @owner.class : @owner_class )
            end
            ass[:app] = asset_owner.app if asset_owner.respond_to?(:app)
            # FIXME! @definer_class is not correct for Spider::HomeController
            raise "Asset type not given for #{src}" unless type
            search_classes = [asset_owner]
            search_classes << @definer_class if @definer_class
            search_classes << Spider.home
            dfnr = @definer_class.superclass if @definer_class && @definer_class.respond_to?(:superclass)
            while dfnr && dfnr < Spider::Widget
                search_classes << dfnr
                dfnr = dfnr.respond_to?(:superclass) ? dfnr.superclass : nil
            end
            res = Spider.find_resource(type.to_sym, src, @path, search_classes)
            raise "Resource #{src} of type #{type} not found" unless res.path
            controller = nil
            if res && res.definer
                controller = res.definer.controller
                if res.definer.is_a?(Spider::Home)
                    ass[:app] = :home
                else
                    ass[:app] = res.definer
                end
            elsif owner_class < Spider::Controller
                controller = owner_class
            end
            ass[:path] = res.path if res
            base_url = nil
            if controller.respond_to?(:pub_url)
                if src[0].chr == '/' 
                    if controller <= Spider::HomeController
                        src = src[(1+controller.pub_path.length)..-1]
                    else
                    # strips the app path from the src. FIXME: should probably be done somewhere else
                        src = src[(2+controller.app.relative_path.length)..-1]
                    end
                end
                base_url = controller.pub_url+'/'
                
            else
                base_url = ''
            end
            ass[:rel_path] = src
            ass[:src] = base_url + src
            ass_info = self.class.asset_types[type]
            if ass_info && ass_info[:processor]
                processor = TemplateAssets.const_get(ass_info[:processor])
                ass = processor.process(ass)
            end
            if cpr = attributes[:compressed] 
                if cpr == true || cpr == "true"
                    ass[:compressed_path] = ass[:path]
                    ass[:compressed_rel_path] = ass[:rel_path]
                    ass[:compressed] = base_url + File.basename(ass[:path])
                else
                    compressed_res = Spider.find_resource(type.to_sym, cpr, @path, [owner_class, @definer_class])
                    ass[:compressed_path] = compressed_res.path
                    ass[:compressed] = base_url+cpr
                end
            end
            ass[:no_compress] = attributes[:"no-compress"]
            ass[:copy_dir] = attributes[:copy_dir]
            ass[:copy_dir] = ass[:copy_dir] =~ /\d+/ ? ass[:copy_dir].to_i : true
            [:gettext, :media, :if_ie_lte, :cdn].each do |key|
                ass[key] = attributes[key] if attributes.key?(key)
            end
            return [ass]
        end
        
        # Returns the root node of the template at given path.
        # Will apply overrides and process extends and inclusions.
        def get_el(path_or_doc=nil)
            path = nil
            doc = nil
            if path_or_doc.is_a?(Hpricot::Doc)
                doc = path_or_doc
                path = @path
            else
                path = path_or_doc
                path ||= @path
                doc = open(path){ |f| Hpricot.XML(f) }
            end
            root = doc.root
            overrides = []
            orig_overrides = @overrides
            @overrides = []
            if root.children
                override_tags.each do |tag|
                    overrides += root.children_of_type('tpl:'+tag)
                end
            end
            overrides.each{ |o| o.set_attribute('class', 'to_delete') }
            root.search('.to_delete').remove
            add_overrides overrides
            our_domain = nil
            if @definer_class
                our_domain = @definer_class.respond_to?(:app) ? @definer_class.app.gettext_domain : 'spider'
            end
            @overrides += orig_overrides
            if root.name == 'tpl:extend'
                orig_overrides = @overrides

                @overrides = []
                ext_src = root.get_attribute('src')
                ext_app = root.get_attribute('app')
                ext_widget = root.get_attribute('widget')
                if ext_widget
                    ext_widget = Spider::Template.get_registered_class(ext_widget)
                    ext_src ||= ext_widget.default_template
                    ext_owner = ext_widget
                    ext_app = ext_widget.app
                elsif ext_app
                    ext_app = Spider.apps_by_path[ext_app]
                    ext_owner = ext_app
                else 
                    ext_owner = @owner.class
                    ext_app = ext_owner.app
                end
                @extended_app = ext_app
                ext_search_paths = nil
                if ext_owner && ext_owner.respond_to?(:template_paths)
                    ext_search_paths = ext_owner.template_paths
                end
                ext = self.class.real_path(ext_src, path, ext_owner, ext_search_paths)
                raise "Extended template #{ext_src} not found (search path #{path}, owner #{ext_owner}, search paths #{ext_search_paths.inspect}" unless ext
                assets = []
                if root.children
                    assets = root.children_of_type('tpl:asset')
                    assets += root.children_of_type('tpl:assets')
                end
                @dependencies << ext
                root = get_el(ext)
                if ext_app.gettext_domain != our_domain
                    root.set_attribute('tpl:text-domain', ext_app.gettext_domain)
                end
                root.children_of_type('tpl:asset').each do |ass|
                    ass_src = ass.get_attribute('src')
                    if ass_src && ass_src[0].chr != '/'
                        # ass.set_attribute('src', "/#{ext_app.relative_path}/#{ass_src}")
                        ass.set_attribute('app', ext_app.relative_path) if ass.get_attribute('app').blank?
                    end
                end
                @overrides += orig_overrides
                if assets && !assets.empty?
                    assets.each do |ass|
                        root.innerHTML += ass.to_html
                    end
                end
            else
                assets_html = ""
                root.search('tpl:include').each do |incl|
                    resource = Spider.find_resource(:views, incl.get_attribute('src'), @path, [@owner.class, @definer_class])
                    src = resource.path
                    raise "Template #{@path} didn't find included '#{incl.get_attribute('src')}'" unless src
                    @dependencies << src
                    incl_el = self.get_el(src)
                    assets = incl_el.children ? incl_el.children_of_type('tpl:asset') : []
                    assets.each{ |ass| 
                        ass.set_attribute('class', 'to_delete')
                        ass_src = ass.get_attribute('src')
                        if ass_src && ass_src[0].chr != '/'
                            if resource.definer.is_a?(Spider::Home)
                                ass.set_attribute('home', 'true')
                            else
                            # ass.set_attribute('src', "/#{resource.definer.relative_path}/#{ass_src}")
                                res_rel_path = if resource.definer.respond_to?(:app)
                                    resource.definer.app.relative_path
                                elsif resource.definer.respond_to?(:relative_path)
                                    resource.definer.relative_path
                                else
                                    nil
                                end
                                ass.set_attribute('app', res_rel_path) if res_rel_path
                            end
                        end
                        assets_html += ass.to_html 
                    }
                    if incl_el.children
                        incl_el.children_of_type('tpl:assets').each do |asss|
                            assets_html += asss.to_html
                        end
                    end
                    incl_el.search('.to_delete').remove
                    td = resource.definer.respond_to?(:app) ? resource.definer.app.gettext_domain : 'spider'
                    if td != our_domain
                        incl_el.set_attribute('tpl:text-domain', td)
                    end
                    incl.swap(incl_el.to_html)
                end
                
                root.search('.to_delete').remove
                root.innerHTML = assets_html + root.innerHTML
            end
            return root
        end
        
        def process_tags(el)
            block = TemplateBlocks.get_block_type(el, true)
            raise "Bad html in #{@path}, can't parse" if el.is_a?(Hpricot::BogusETag)
            if block == :Tag
                sp_attributes = {}
                # FIXME: should use blocks instead
                el.attributes.to_hash.each do |key, value|
                    if key[0..1] == 'sp'
                        sp_attributes[key] = value
                        el.remove_attribute(key)
                    end
                end
                klass = Spider::Template.get_registered_class(el.name)
                tag = klass.new(el)
                res = process_tags(Hpricot(tag.render).root)
                sp_attributes.each{ |key, value| res.set_attribute(key, value) }
                return res
            else
                el.each_child do |child|
                    next if child.is_a?(Hpricot::Text) || child.is_a?(Hpricot::Comment)
                    el.replace_child(child, process_tags(child))
                end
            end
            return el
        end
        
        # The full path of a template mentioned in this one.
        def real_path(path)
            self.class.real_path(path, File.dirname(@path), [@owner.class, @definer_class])
        end
            
        
        def loaded?
            @compiled ? true : false
        end
        
        # Adds a widget instance to the template.
        # This method is usually not called directly; widgets are added during the template
        # init phase.
        def add_widget(id, widget, attributes=nil, content=nil, template=nil)
            @widgets[id.to_sym] ||= widget
            widget.id = id
            widget.id_path = @id_path + [id]
            if attributes # don't use merge to trigger custom []=(k, v) method
                attributes.each{ |k, v| widget.attributes[k] = v }
            end
            widget.containing_template = self
            widget.template = template if template
            widget.parent = @owner
            widget.parse_runtime_content_xml(content, @path) if content
            if @widget_procs[id.to_sym]
                @widget_procs[id.to_sym].each do |wp|
                    apply_widget_proc(widget, wp)
                end
            end
            widget
        end
        
        def find_widget(path)
            return @widgets[path.to_sym]
        end
        
        # Does the init phase (evals the template's compiled _init.rb_).
        def init(scene)
#            Spider::Logger.debug("Template #{@path} INIT")
            load unless loaded?
            # debug("Template #{@path} init")
            # debug(@compiled.init_code)
            @scene = scene
            instance_eval(@compiled.init_code, @compiled.cache_path+'/init.rb')
            @init_done = true
        end
        
        
        def init_done?
            @init_done
        end
        
        # Calls the before method of all widget instances.
        def do_widgets_before
            @widgets.each do |id, w|
                act = (@_action_to == id) ? @_action : ''
                w.widget_before(act) unless w.before_done?
            end
        end
        
        # Calls the run method on all widget instances.
        def run_widgets
            @widgets.each do |id, w|
                w.run if w.run? && !w.did_run?
            end
            
        end
        
        # Does #do_widgets_before and then #run_widgets.
        def exec
            do_widgets_before
            run_widgets
        end
        
        # Does the render phase.
        # Will execute the following steps (if needed):
        # - load
        # - init
        # - exec
        # - eval the template's compiled run code.
        def render(scene=nil)
            prev_domain = nil
            if @definer_class
                td = @definer_class.respond_to?(:app) ? @definer_class.app.gettext_domain : 'spider'
                prev_domain = Spider::GetText.set_domain(td)
            end
            scene ||= @scene
            load unless loaded?
            init(scene) unless init_done?
            exec
            @content.merge!(@widgets)
            # if Spider.conf.get('template.safe')
            #     debug("RENDERING IN SAFE MODE!")
            #     debug(@compiled.run_code)
            #     # FIXME: must send header before safe mode
            #     current_thread = Thread.current
            #     t = Thread.new { 
            #         Thread.current[:stdout] = current_thread[:stdout]
            #         $SAFE = 4
            #         scene.instance_eval("def __run_template\n"+@compiled.run_code+"end\n", @compiled.cache_path+'/run.rb')
            #         scene.__run_template
            #         scene.__run_template do |widget|
            #             @content[widget].run
            #         end
            #     }
            #     t.join
            # else
            scene.instance_eval("def __run_template\n"+@compiled.run_code+"end\n", @compiled.cache_path+'/run.rb', 0)
            scene.__run_template do |yielded|
                if yielded == :_parent
                    @owner.parent.template.content.merge!(@content)
                    @owner.parent.template.run_block
                else
                    @content[yielded].render if @content[yielded]
                end
            end
            Spider::GetText.restore_domain(prev_domain) if prev_domain
            # end
        end
        
        def run_block
            @scene.__run_block do |yielded, block|
                @content[yielded].render if @content[yielded]
            end
        end
        
        # Alias for #render.
        def run
            render(@scene)
        end
        

        def inspect
            self.class.to_s
        end
        
        def add_subtemplate(id, template, owner) # :nodoc:
            @subtemplates[id] = template
            @subtemplate_owners[id] = owner
        end
        
        def add_widget_template(template, owner_class)
            template.owner_class = owner_class
            @widget_templates << template
        end
        
        
        def load_subtemplate(id, options={}) # :nodoc:
            load unless loaded?
            return nil unless @compiled.subtemplates[id]
            t = Template.new
            t.asset_profiles = options[:asset_profiles] if options[:asset_profiles]
            t.compiled = @compiled.subtemplates[id]
            return t
        end
        
        def add_overrides(overrides)
            overrides.each do |ov|
                w = ov.get_attribute('widget')
                if w
                    first, rest = w.split('/', 2)
                    if rest
                        ov.set_attribute('widget', rest)
                    else
                        ov.remove_attribute('widget')
                    end
                    @widgets_overrides[first] ||= []
                    @widgets_overrides[first] << ov
                else
                    @overrides << ov
                end
            end
        end
        
        def overrides_for(widget_id)
            @widgets_overrides[widget_id] || []
        end

        def apply_overrides(el)
            info_els = nil
            if el.children
                info_els = Hpricot::Elements[*(el.children_of_type('tpl:asset')+
                    el.children_of_type('tpl:assets'))]
                info_els.remove
            end
            if @overrides
                @overrides.each{ |o| apply_override(el, o) }
            end
            if info_els
                el.innerHTML = info_els.to_s + el.innerHTML
            end
            el
        end
        
        # Applies an override to an (Hpricot) element.
        def apply_override(el, override)
            if override.is_a?(Proc)
                return override.call(el)
            end
            search_string = override.get_attribute('search')
            override.name = 'tpl:override-content' if override.name == 'tpl:inline-override'
            if search_string
                # # Fix Hpricot bug!
                # search_string.gsub!(/nth-child\((\d+)\)/) do |match|
                #     "nth-child(#{$1.to_i-2})"
                # end
                found = el.parent.search(search_string)
            elsif override.name == 'tpl:content'
                found = el.search("tpl:placeholder[@name='#{override.get_attribute('name')}']")
            else
                if ['sp:template'].include?(el.name)
                    found = el.children.select{ |child| child.is_a?(Hpricot::Elem) }
                else
                    found = [el]
                end
            end
            
            if override.name == 'tpl:delete'
                found.remove
            else
                td = nil
                orig_td = nil
                if @extended_app
                    td = @definer_class.respond_to?(:app) ? @definer_class.app.gettext_domain : nil
                    orig_td = @extended_app.gettext_domain
                elsif @subtemplate_of
                    td = @subtemplate_of.respond_to?(:app) ? @subtemplate_of.app.gettext_domain : nil
                    orig_td = @definer_class.respond_to?(:app) ? @definer_class.app.gettext_domain : nil
                end
                if td && orig_td && td != orig_td
                    override.innerHTML = '<tpl:pass tpl:text-domain="'+td+'">'+override.innerHTML+'</tpl:pass>'                
                end
                found.each do |f|
                    o_doc = nil
                    if override.name == 'tpl:override-content'
                        overridden = f.innerHTML
                        f.innerHTML = override.innerHTML
                        f.search('tpl:overridden').each do |o| 
                            ovr = overridden
                            if o_search = o.get_attribute('search')
                                o_doc ||= Hpricot("<o>#{overridden}</o>")
                                ovr = o_doc.root.search(o_search).to_html
                            end
                            if orig_td
                                ovr = '<tpl:pass tpl:text-domain="'+orig_td+'">'+ovr+'</tpl:pass>'
                            end
                            o.swap(ovr)
                        end
                    elsif override.name == 'tpl:override' || override.name == 'tpl:content'
                        if orig_td
                            f.set_attribute('tpl:text-domain', orig_td)
                        end
                        overridden = f.to_html
                        parent = f.parent
                        if f == el
                            f.innerHTML = override.innerHTML
                        else
                            f.swap(override.innerHTML)
                        end
                        parent.search('tpl:overridden').each do |o| 
                            ovr = overridden
                            if o_search = o.get_attribute('search')
                                o_doc ||= Hpricot("<o>#{overridden}</o>")
                                ovr = o_doc.root.search(o_search).to_html
                            end
                            o.swap(ovr)
                        end
                    elsif override.name == 'tpl:override-attr'
                        f.set_attribute(override.get_attribute("name"), override.get_attribute("value"))
                    elsif override.name == 'tpl:append-attr'
                        a = f.get_attribute(override.get_attribute("name")) || ''
                        a += ' ' unless a.blank?
                        a += override.get_attribute("value")
                        f.set_attribute(override.get_attribute("name"), a)
                    elsif override.name == 'tpl:append'
                        f.innerHTML += override.innerHTML
                    elsif override.name == 'tpl:prepend'
                        f.innerHTML = override.innerHTML + f.innerHTML
                    elsif override.name == 'tpl:before'
                        f.before(override.innerHTML)
                    elsif override.name == 'tpl:after'
                        f.after(override.innerHTML)
                    end

                end
            end
        end
        

        def with_widget(path, &proc)
            first, rest = path.split('/', 2)
            @widget_procs[first.to_sym] ||= []
            wp = {:target => rest, :proc => proc }
            @widget_procs[first.to_sym] << wp
            if @widgets[first.to_sym]
                apply_widget_proc(@widgets[first.to_sym], wp)
            end
        end
        
        def apply_widget_proc(widget, wp)
            if wp[:target]
                widget.with_widget(wp[:target], &wp[:proc])
            else
                widget.instance_eval(wp[:proc])
            end
        end
        
        def inspect
            "#<#{self.class}:#{self.object_id} #{@path}>"
        end
        
        ExpressionOutputRegexp = /\{?\{\s([^\s].*?)\s\}\}?/
        GettextRegexp = /([snp][snp]?)?_\(([^\)]+)?\)(\s%\s([^\s,]+(?:,\s*\S+\s*)?))?/
        ERBRegexp = /(<%(.+)?%>)/
        SceneVarRegexp = /@(\w[\w\d_]+)/
        
        def self.scan_text(text)
            text = text.gsub(/\302\240/u, ' ') # remove annoying fake space
            scanner = ::StringScanner.new(text)
            pos = 0
            c = ""
            while scanner.scan_until(Regexp.union(ExpressionOutputRegexp, GettextRegexp, ERBRegexp))
                t = scanner.pre_match[pos..-1]
                pos = scanner.pos
                yield :plain, t, t if t && t.length > 0
                case scanner.matched
                when ExpressionOutputRegexp
                    if scanner.matched[1].chr == '{'
                        yield :escaped_expr, $1, scanner.matched
                    else
                        yield :expr, $1, scanner.matched
                    end
                when GettextRegexp
                    gt = {:val => $2, :func => $1}
                    gt[:vars] = $4 if $3 # interpolated vars
                    yield :gettext, gt, scanner.matched
                when ERBRegexp
                    yield :erb, $1, scanner.matched
                end
            end
            yield :plain, scanner.rest, scanner.rest
        end
        
        def self.scan_scene_vars(str)
            scanner = ::StringScanner.new(str)
            pos = 0
            while scanner.scan_until(SceneVarRegexp)
                text = scanner.pre_match[pos..-1]
                yield :plain, text, text if text &&  text.length > 0
                pos = scanner.pos
                yield :var, scanner.matched[1..-1]
            end
            yield :plain, scanner.rest
        end
                
    end
    
    # Class holding compiled template code.
    
    class CompiledTemplate
        attr_accessor :block, :source_path, :cache_path, :subtemplates, :devel_info, :assets
        
        
        def initialize()
            @subtemplates = {}
            @subtemplate_owners = {}
            @devel_info = {}
        end
        
        def init_code
            @block.init_code
        end
        
        def run_code
            @block.run_code
        end
        
        def collect_mtimes
            mtimes = {@source_path => File.mtime(@source_path)}
            @subtemplates.each{ |id, sub| mtimes.merge(sub.collect_mtimes)}
            return mtimes
        end
        
    end
    
    class TemplateCompileError < RuntimeError
    end
    
    class DocType
        attr_reader :type, :variant
        
        def initialize(type_or_str)
            if type_or_str.is_a?(Symbol)
                @type = type_or_str
            else
                parse(type_or_str.to_s)
            end
        end
        
        def parse(str)
            if str =~ /DOCTYPE HTML PUBLIC.+\sHTML/i
                @type = :html4
            elsif str =~ /DOCTYPE HTML PUBLIC.+\sXHTML/i
                @type = :xhtml
            elsif str.downcase == '<!doctype html>'
                @type = :html5
            end
            if str =~ /strict/i
                @variant = :strict
            elsif str =~ /transitional/i
                @variant = :transitional
            end
        end
        
        def html?
            @type == :html4 || @type == :html5
        end
        
        def xhtml?
            @type == :xhtml
        end
        
        def strict?
            @variant == :strict
        end
        
    end
    
end
