require 'hpricot'
require 'spiderfw/templates/template_blocks'
require 'spiderfw/cache/template_cache'


module Spider
    
    class Template
        include Logger
        
        attr_accessor :widgets, :overrides, :compiled, :id_path
        attr_accessor :request, :response
        attr_reader :path, :subtemplates, :widgets
        
        @@registered = {}
        @@namespaces = {}
        @@cache = TemplateCache.new(Spider.paths[:var]+'/cache/templates')
        
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

            def load(path, scene={})
                raise RuntimeError, "Template #{path} does not exist" unless File.exist?(path)
                template = self.new(scene)
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
        
        
        
        def initialize(path=nil, scene=nil)
            @path = path
            @scene = scene
            @widgets = {}
            @subtemplates = {}
            @id_path = []
            @resources = []
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
            doc = open(@path){ |f| Hpricot.XML(f) }
            root = doc.root
            @overrides.each{ |o| apply_override(root, o) } if (@overrides)
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
            return compiled
        end
            
        
        def loaded?
            @compiled ? true : false
        end
        
        def init_done?
            @init_done ? true : false
        end
        
        def init_sub_done?
            @init_sub_done ? true : false
        end
        
        def init_sub_done=(val)
            @init_sub_done = val
        end
        
        def add_widget(id, widget, attributes=nil, content=nil, template=nil)
            @widgets[id.to_sym] ||= widget
            widget.id_path = @id_path + [id]
            widget.attributes = attributes if attributes
            widget.template = template if template
            widget.parse_content_xml(content) if content
        end
        
        #def init(request, scene)
        def init(scene=nil)
#            Spider::Logger.debug("Template #{@path} INIT")
            load unless loaded?
            scene ||= (@scene || Scene.new)       
            scene = Scene.new(scene) if scene.class == Hash
            # debug("Template #{@path} init")
            # debug(@compiled.init_code)
            instance_eval(@compiled.init_code, @compiled.cache_path+'/init.rb')
            @init_done = true
        end
        
        def init_sub
            @widgets.each do |id, widget|
                widget.init_widget
            end
            @init_sub_done = true
        end
        
        def prepare
        end
        
        def render(scene=nil)
            load unless loaded?
            scene ||= (@scene || Scene.new)       
            scene = Scene.new(scene) if scene.class == Hash
            # debug("Template #{@path} rendering with scene:")
            # debug(scene)
            init(scene) unless init_done?
            init_sub unless init_sub_done?
            scene.widgets ||= {}
            scene.widgets.merge!(@widgets)
#            Spider::Logger.debug("Template #{@path} RUN")
            scene.instance_eval(@compiled.run_code, @compiled.cache_path+'/run.rb')
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
            return unless search_string
            # Fix Hpricot bug!
            search_string.gsub!(/nth-child\((\d+)\)/) do |match|
                "nth-child(#{$1.to_i-2})"
            end
            found = el.parent.search(search_string)
            found.each do |f|
                if (override.name == 'tpl:override-content')
                    overridden = f.innerHTML
                    f.innerHTML = override.innerHTML
                    f.search('tpl:overridden').each{ |o| o.swap(overridden) }
                elsif (override.name == 'tpl:override')
                    overridden = f.to_html
                    f.swap(override.innerHTML)
                    f.search('tpl:overridden').each{ |o| o.swap(overridden) }
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
        attr_accessor :block, :source_path, :cache_path, :subtemplates
        
        def initialize()
            @subtemplates = {}
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