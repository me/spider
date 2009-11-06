require 'hpricot'
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
        attr_accessor :request, :response, :owner, :owner_class
        attr_accessor :mode # :widget, ...
        attr_reader :overrides, :path, :subtemplates, :widgets
        
        @@registered = {}
        @@widget_plugins = {}
        @@namespaces = {}
        @@cache = TemplateCache.new(Spider.paths[:var]+'/cache/templates')
        @@overrides = ['content', 'override', 'override-content', 'override-attr', 'append-attr',
                        'append', 'prepend', 'delete', 'before', 'after']
                        
        @@asset_types = {
            :css => {},
            :js => {},
            :less => {:processor => :Less}
        }
        
        class << self
            
            # Returns the class TemplateCache instance
            def cache
                @@cache
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
                if (tag) # that is, if there is a ns
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
                if (@@registered[name])
                    klass = @@registered[name]
                else
                    ns, tag = name.split(':')
                    klass = @@namespaces[ns].get_tag(tag) if (tag && @@namespaces[ns])
                end
                return nil unless klass
                klass = const_get_full(klass) if klass.is_a?(Symbol)
                return klass
            end
            
            # Returns the view path (see #Spider::find_asset)
            def real_path(path, cur_path=nil, owner_class=nil, search_paths=[])
                Spider.find_resource_path(:views, path, cur_path, owner_class, search_paths)
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
            def override_tags
                @@overrides
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
            @subtemplate_owners = {}
            @id_path = []
            @assets = []
            @content = {}
            @dependencies = []
            @overrides = []
            @widgets_overrides = {}
            @widget_procs = {}
        end
        
        # Sets the scene.
        def bind(scene)
            @scene = scene
            return self
        end
        
        
        # Loads the compiled template (from cache if available).
        def load(path=nil)
            @path = real_path(path) if path
#            debug("TEMPLATE LOADING #{@path}")
            cache_path = @path.sub(Spider.paths[:root], 'ROOT').sub(Spider.paths[:spider], 'SPIDER')
            @compiled = self.class.cache.fetch(cache_path) do
                compile(:mode => @mode)
            end
        end
        
        # Recompiles the template; returns a CompiledTemplate.
        def compile(options={})
            compiled = CompiledTemplate.new
            compiled.source_path = @path
            root = get_el(@path)
            el = process_tags(root)
            @overrides.each{ |o| apply_override(root, o) } if (@overrides)
            root.search('tpl:placeholder').remove # remove empty placeholders
            res =  root.children_of_type('tpl:asset')
            res_init = ""
            res.each do |r|
                r.set_attribute('class', 'to_delete')
                pr = parse_asset(r.attributes['type'], r.attributes['src'], r.attributes)
                assets << pr
                res_init += "@assets << { 
                    :type => :#{pr[:type]}, 
                    :src => '#{pr[:src]}',
                    :path => '#{pr[:path]}',
                    :if => '#{pr[:if]}'
                }\n"
            end
            root.search('.to_delete').remove
            root_block = TemplateBlocks.parse_element(root, self.class.allowed_blocks, self)
            options[:root] = true
            options[:owner] = @owner
            options[:owner_class] = @owner_class || @owner.class
            options[:template_path] = @path
            compiled.block = root_block.compile(options)
            subtemplates.each do |id, sub|
                sub.owner_class = @subtemplate_owners[id]
                compiled.subtemplates[id] = sub.compile(options.merge({:mode => :widget})) # FIXME! :mode => :widget is wrong,
                # it's just a quick kludge
            end
            compiled.block.init_code = res_init + compiled.block.init_code
            compiled.devel_info["source.xml"] = root.to_html
            return compiled
        end
        
        # Processes an asset. Returns an hash with :type, :src, :path.
        def parse_asset(type, src, attributes={})
            # FIXME: use Spider.find_asset ?
            ass = {:type => type}
            if (attributes['app'])
                owner_class = Spider.apps_by_path[attributes['app']]
            else
                owner_class = (@owner ? @owner.class : @owner_class )
            end
            res = Spider.find_resource(type.to_sym, src, @path, owner_class)
            controller = nil
            if (res && res.definer)
                controller = res.definer.controller
            end
            ass[:path] = res.path if res
            if controller.respond_to?(:pub_url)
                ass[:src] = controller.pub_url + '/' + src
            else
                ass[:src] = src
            end
            ass_info = self.class.asset_types[type]
            if (ass_info && ass_info[:processor])
                processor = TemplateAssets.const_get(ass_info[:processor])
                ass = processor.process(ass)
            end
            if attributes['sp:if']
                ass[:if] = Spider::TemplateBlocks::Block.vars_to_scene(attributes['sp:if']).gsub("'", "\\'") 
            end
            return ass
        end
        
        # Returns the root node of the template at given path.
        # Will apply overrides and process extends and inclusions.
        def get_el(path=nil)
            path ||= @path
            doc = open(path){ |f| Hpricot.XML(f) }
            root = doc.root
            overrides = []
            override_tags.each do |tag|
                overrides += root.children_of_type('tpl:'+tag)
            end
            overrides.each{ |o| o.set_attribute('class', 'to_delete') }
            root.search('.to_delete').remove
            add_overrides overrides
            if (root.name == 'tpl:extend')
                ext_src = root.attributes['src']
                ext_app = root.attributes['app']
                ext_widget = root.attributes['widget']
                if ext_widget
                    ext_widget = Spider::Template.get_registered_class(ext_widget)
                    ext_src ||= ext_widget.default_template
                    ext_owner = ext_widget
                elsif ext_app
                    ext_app = Spider.apps_by_path[ext_app]
                    ext_owner = ext_widget
                end
                ext_search_paths = nil
                if (ext_owner && ext_owner.respond_to?(:template_paths))
                    ext_search_paths = ext_owner.template_paths
                end 
                ext = self.class.real_path(ext_src, @path, ext_owner, ext_search_paths)
                assets = root.children_of_type('tpl:asset')
                @dependencies << ext
                tpl = Template.new(ext)
                root = get_el(ext)
                if (assets && !assets.empty?)
                    assets.each do |ass|
                        root.innerHTML += ass.to_html
                    end
                end
            else
                root.search('tpl:include').each do |incl|
                    src = real_path(incl.attributes['src'])
                    @dependencies << src
                    incl.swap(self.get_el(src).to_html)
                end
            end
            return root
        end
        
        def process_tags(el)
            block = TemplateBlocks.get_block_type(el, true)
            raise "Bad html in #{@path} at '#{el}', can't parse" if (el == Hpricot::BogusETag)
            if (block == :Tag)
                sp_attributes = {}
                # FIXME: should use blocks instead
                el.attributes.each do |key, value|
                    if (key[0..1] == 'sp')
                        sp_attributes[key] = value
                        el.raw_attributes.delete(key)
                    end
                end
                klass = Spider::Template.get_registered_class(el.name)
                tag = klass.new(el)
                res = process_tags(Hpricot(tag.render).root)
                sp_attributes.each{ |key, value| res.raw_attributes[key] = value }
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
            self.class.real_path(path, File.dirname(@path), @owner.class)
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
            if (attributes) # don't use merge to trigger custom []=(k, v) method
                attributes.each{ |k, v| widget.attributes[k] = v }
            end
            widget.containing_template = self
            widget.template = template if template
            widget.parent = @owner
            widget.parse_runtime_content_xml(content, @path) if content
            if (@widget_procs[id.to_sym])
                @widget_procs[id.to_sym].each do |wp|
                    apply_widget_proc(widget, wp)
                end
            end
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
                w.run unless w.did_run?
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
            scene.__run_template do |widget|
                @content[widget].render if @content[widget]
            end
            # end
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
        
        
        def load_subtemplate(id) # :nodoc:
            load unless loaded?
            return nil unless @compiled.subtemplates[id]
            t = Template.new
            t.compiled = @compiled.subtemplates[id]
            return t
        end
        
        def add_overrides(overrides)
            overrides.each do |ov|
                w = ov.attributes['widget']
                if (w)
                    first, rest = w.split('/', 2)
                    if (rest)
                        ov.raw_attributes['widget'] = rest
                    else
                        ov.raw_attributes.delete('widget')
                    end
 #                   debugger
                    @widgets_overrides[first] ||= []
                    @widgets_overrides[first] << ov
                else
                    @overrides << ov
                end
            end
        end
        
        def overrides_for(widget_id)
#            debugger
            @widgets_overrides[widget_id] || []
        end
        
        # Applies an override to an (Hpricot) element.
        def apply_override(el, override)
            search_string = override.attributes['search']
            override.name = 'tpl:override-content' if override.name == 'tpl:inline-override'
            if (search_string)
                # # Fix Hpricot bug!
                # search_string.gsub!(/nth-child\((\d+)\)/) do |match|
                #     "nth-child(#{$1.to_i-2})"
                # end
                found = el.parent.search(search_string)
            elsif (override.name == 'tpl:content')
                found = el.search("tpl:placeholder[@name='#{override.attributes['name']}']")
            else
                found = [el]
            end
            if (override.name == 'tpl:delete')
                found.remove
            else
                found.each do |f|
                    if (override.name == 'tpl:override-content')
                        overridden = f.innerHTML
                        f.innerHTML = override.innerHTML
                        f.search('tpl:overridden').each{ |o| o.swap(overridden) }
                    elsif (override.name == 'tpl:override' || override.name == 'tpl:content')
                        overridden = f.to_html
                        parent = f.parent
                        f.swap(override.innerHTML)
                        parent.search('tpl:overridden').each{ |o| o.swap(overridden) }
                    elsif (override.name == 'tpl:override-attr')
                        f.set_attribute(override.attributes["name"], override.attributes["value"])
                    elsif (override.name == 'tpl:append-attr')
                        f.set_attribute(override.attributes["name"], \
                        (f.attributes[override.attributes["name"]] || '')+override.attributes["value"]) 
                    elsif (override.name == 'tpl:append')
                        f.innerHTML += override.innerHTML
                    elsif (override.name == 'tpl:prepend')
                        f.innerHTML = override.innerHTML + f.innerHTML
                    elsif (override.name == 'tpl:before')
                        f.before(override.innerHTML)
                    elsif (override.name == 'tpl:after')
                        f.after(override.innerHTML)
                    end
                end
            end
        end
        
        # Template assets.
        def assets
            res = []
            @assets.each do |ass|
                 # FIXME: is this the best place to check if? Maybe it's better to do it when printing resources?
                res << ass unless !ass[:if].empty? && !@scene.instance_eval(ass[:if])
            end
            return res
        end
        
        # Assets for the template and contained widgets.
        def all_assets
            res = assets
            seen = {}
            @widgets.each do |id, w|
#                next if seen[w.class]
                seen[w.class] = true
                res += w.assets
            end
            return res
        end
        
        def with_widget(path, &proc)
            first, rest = path.split('/', 2)
            @widget_procs[first.to_sym] ||= []
            wp = {:target => rest, :proc => proc }
            @widget_procs[first.to_sym] << wp
            if (@widgets[first.to_sym])
                apply_widget_proc(@widgets[first.to_sym], wp)
            end
        end
        
        def apply_widget_proc(widget, wp)
            if (wp[:target])
                widget.with_widget(wp[:target], &wp[:proc])
            else
                widget.instance_eval(wp[:proc])
            end
        end
            
        
    end
    
    # Class holding compiled template code.
    
    class CompiledTemplate
        attr_accessor :block, :source_path, :cache_path, :subtemplates, :devel_info
        
        
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
    
end