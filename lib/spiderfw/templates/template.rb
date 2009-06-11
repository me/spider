require 'hpricot'
require 'spiderfw/templates/template_blocks'
require 'spiderfw/cache/template_cache'


module Spider
    
    class Template
        include Logger
        
        attr_accessor :_action, :_action_to
        attr_accessor :widgets, :overrides, :compiled, :id_path
        attr_accessor :request, :response, :owner
        attr_reader :path, :subtemplates, :widgets
        
        @@registered = {}
        @@namespaces = {}
        @@cache = TemplateCache.new(Spider.paths[:var]+'/cache/templates')
        @@overrides = ['content', 'override', 'override-content', 'override-attr',
                        'append', 'prepend', 'delete', 'before', 'after']
        
        class << self
            
            def cache
                @@cache
            end
        
            def allow_blocks(*tags)
                @allowed_blocks = tags
            end

            def allowed_blocks
                @allowed_blocks
            end

            def load(path)
                raise RuntimeError, "Template #{path} does not exist" unless File.exist?(path)
                template = self.new(path)
                template.load(path)
                return template
            end
            
            def register(tag, symbol_or_class)
                @@registered[tag] = symbol_or_class
            end
            
            def registered
                @@registered
            end
            
            def registered?(tag)
                return true if @@registered[tag]
                ns, tag = tag.split(':')
                if (tag) # that is, if there is a ns
                    return false unless @@namespaces[ns]
                    return @@namespaces[ns].has_tag?(tag)
                end
                return false
            end
            
            def register_namespace(ns, mod)
                @@namespaces[ns] = mod
            end
            
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
            
        end
        
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
        
        def bind(scene)
            @scene = scene
            return self
        end
        
        
        def load(path=nil)
            @path = path if path
#            debug("TEMPLATE LOADING #{@path}")
            cache_path = @path.sub(Spider.paths[:root], 'ROOT').sub(Spider.paths[:spider], 'SPIDER')
            @compiled = self.class.cache.fetch(cache_path) do
                compile
            end
        end
        
        def compile
            compiled = CompiledTemplate.new
            compiled.source_path = @path
            root = get_el(@path)
            @overrides.each{ |o| apply_override(root, o) } if (@overrides)
            root.search('tpl:placeholder').remove # remove empty placeholders
            res =  root.children_of_type('tpl:resource')
            res_init = ""
            res.each do |r|
                @resources << { :type => r.attributes['type'], :src => r.attributes['src'], :path => File.dirname(@path) }
                res_init += "@resources << { :type => :#{r.attributes['type']}, :src => '#{r.attributes['src']}', :path => '#{File.dirname(@path)}' }\n"
            end
            root.search('tpl:resource').remove
            root_block = TemplateBlocks.parse_element(root, self.class.allowed_blocks, self)
            compiled.block = root_block.compile
            subtemplates.each do |id, sub|
                compiled.subtemplates[id] = sub.compile
            end
            compiled.block.init_code = res_init + compiled.block.init_code
            compiled.devel_info["source.xml"] = root.to_html
            return compiled
        end
        
        def get_el(path)
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
                    src = real_path(incl.attributes[:src])
                    @dependencies << src
                    tpl = Template.new(src)
                    incl.swap(tpl.get_el.to_html)
                end
            end
            return root
        end
        
        def real_path(path)
            # FIXME: security check for allowed paths?
            path.sub!(/^ROOT/, Spider.paths[:root])
            path.sub!(/^SPIDER/, $SPIDER_PATH)
            return path
        end
            
        
        def loaded?
            @compiled ? true : false
        end
                
        def init_sub_done=(val)
            @init_sub_done = val
        end
        
        def execute_done
            @execute_done = true
        end
        
        def execute_done?
            @execute_done
        end
        
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
            widget.parse_content_xml(content) if content
        end
        
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
        
        def do_widgets_before
            @widgets.each do |id, w|
                act = (@_action_to == id) ? @_action : ''
                w.before(act) unless w.before_done?
            end
        end
        
        def run_widgets
            @widgets.each do |id, w|
                w.run unless w.did_run?
            end
            
        end
        
        def exec
            do_widgets_before
            run_widgets
        end
        
  
        
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
        
        def run
            render(@scene)
        end
        

        def inspect
            self.class.to_s
        end
        
        def add_subtemplate(id, template)
            @subtemplates[id] = template
        end
        
        def load_subtemplate(id)
            load unless loaded?
            return nil unless @compiled.subtemplates[id]
            t = Template.new
            t.compiled = @compiled.subtemplates[id]
            return t
        end
        
        def apply_override(el, override)
            search_string = override.attributes['search']
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
        
        def resources
            res = @resources.clone
            return res
        end
        
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