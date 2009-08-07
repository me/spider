require 'hpricot'
require 'spiderfw/templates/template_blocks'
require 'spiderfw/cache/template_cache'
begin
    require 'less'
    require 'spiderfw/templates/resources/less'
rescue LoadError
end


module Spider
    
    module TemplateResources; end
    
    # This class manages SHTML templates.
    
    class Template
        include Logger
        
        attr_accessor :_action, :_action_to
        attr_accessor :widgets, :overrides, :compiled, :id_path
        attr_accessor :request, :response, :owner
        attr_accessor :mode # :widget, ...
        attr_reader :path, :subtemplates, :widgets
        
        @@registered = {}
        @@namespaces = {}
        @@cache = TemplateCache.new(Spider.paths[:var]+'/cache/templates')
        @@overrides = ['content', 'override', 'override-content', 'override-attr',
                        'append', 'prepend', 'delete', 'before', 'after']
                        
        @@resource_types = {
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
            
            def resource_types # :nodoc:
                @@resource_types
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
            
            # Returns the view path (see #Spider::find_resource)
            def real_path(path, cur_path=nil, owner_class=nil)
                Spider.find_resource(:views, path, cur_path, owner_class)
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
            @id_path = []
            @resources = []
            @content = {}
            @dependencies = []
            @overrides = []
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
            @overrides.each{ |o| apply_override(root, o) } if (@overrides)
            root.search('tpl:placeholder').remove # remove empty placeholders
            res =  root.children_of_type('tpl:resource')
            res_init = ""
            res.each do |r|
                pr = parse_resource(r.attributes['type'], r.attributes['src'], r.attributes)
                resources << pr
                res_init += "@resources << { 
                    :type => :#{pr[:type]}, 
                    :src => '#{pr[:src]}',
                    :path => '#{pr[:path]}'
                }\n"
            end
            root.search('tpl:resource').remove
            root_block = TemplateBlocks.parse_element(root, self.class.allowed_blocks, self)
            compiled.block = root_block.compile(options)
            subtemplates.each do |id, sub|
                compiled.subtemplates[id] = sub.compile(options)
            end
            compiled.block.init_code = res_init + compiled.block.init_code
            compiled.devel_info["source.xml"] = root.to_html
            return compiled
        end
        
        # Processes a resource. Returns an hash with :type, :src, :path.
        def parse_resource(type, src, attributes={})
            # FIXME: use Spider.find_resource ?
            res = {:type => type}
            if @owner && @owner.class.respond_to?(:pub_url)
                res[:src] = @owner.class.pub_url + '/' + src
                res[:path] = @owner.class.pub_path + '/' + src
            else
                res[:src] = src
                res[:path] = src
            end
            res_info = self.class.resource_types[type]
            if (res_info && res_info[:processor])
                processor = TemplateResources.const_get(res_info[:processor])
                res = processor.process(res)
            end
            return res
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
            @overrides += overrides
            if (root.name == 'sp:template' && ext = root.attributes['extend'])
                ext = real_path(ext)
                @dependencies << ext
                tpl = Template.new(ext)
                root = get_el(ext)
            else
                root.search('tpl:include').each do |incl|
                    src = real_path(incl.attributes['src'])
                    @dependencies << src
                    incl.swap(self.get_el(src).to_html)
                end
            end
            return root
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
            widget.parse_runtime_content_xml(content) if content
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
                w.before(act) unless w.before_done?
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
                @content[widget].render
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
        
        def add_subtemplate(id, template) # :nodoc:
            @subtemplates[id] = template
        end
        
        
        def load_subtemplate(id) # :nodoc:
            load unless loaded?
            return nil unless @compiled.subtemplates[id]
            t = Template.new
            t.compiled = @compiled.subtemplates[id]
            return t
        end
        
        # Applies an override to an (Hpricot) element.
        def apply_override(el, override)
            search_string = override.attributes['search']
            override.name = 'tpl:override-content' if override.name == 'tpl:inline-override'
            if (search_string)
                # Fix Hpricot bug!
                search_string.gsub!(/nth-child\((\d+)\)/) do |match|
                    "nth-child(#{$1.to_i-2})"
                end
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
    #                    debugger
                        overridden = f.to_html
                        parent = f.parent
                        f.swap(override.innerHTML)
                        parent.search('tpl:overridden').each{ |o| o.swap(overridden) }
                    elsif (override.name == 'tpl:override-attr')
                        f.set_attribute(override.attributes["name"], override.attributes["value"])
                    elsif (override.name == 'tpl:append')
                        f.innerHTML += override.innerHTML
                    elsif (override.name == 'tpl:prepend')
                        f.innerHTML = override.innerHTML + f.innerHTML
                    elsif (override.name == 'tpl:before')
                        f.parent.innerHTML = override.innerHTML + f.parent.innerHTML
                    elsif (override.name == 'tpl:after')
                        f.parent.innerHTML += override.innerHTML
                    end
                end
            end
        end
        
        # Template resources.
        def resources
            res = @resources.clone
            return res
        end
        
        # Resources for the template and contained widgets.
        def all_resources
            res = resources
            seen = {}
            @widgets.each do |id, w|
                next if seen[w.class]
                seen[w.class] = true
                res += w.resources
            end
            return res
        end
            
        
    end
    
    # Class holding compiled template code.
    
    class CompiledTemplate
        attr_accessor :block, :source_path, :cache_path, :subtemplates, :devel_info
        
        
        def initialize()
            @subtemplates = {}
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