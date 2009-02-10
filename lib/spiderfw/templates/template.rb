require 'hpricot'
require 'spiderfw/templates/template_blocks'
require 'spiderfw/cache/template_cache'


module Spider
    
    class Template
        include Logger
        
        attr_accessor :widgets
        attr_reader :path
        
        @@registered = {}
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
                return @@registered[tag] ? true : false
            end
            
            def get_registered_class(name)
                klass = Spider::Template.registered[name]
                klass = const_get_full(klass) if klass.is_a?(Symbol)
                return klass
            end
            
        end
        
        
        
        def initialize(scene={})
            @scene = scene
            @widgets = {}
        end
        
        def bind(scene)
            @scene = scene
            return self
        end
        
        
        def load(path)
            debug("TEMPLATE LOADING #{path}")
            @path = path
            cache_path = path.sub(Spider.paths[:root], 'ROOT').sub(Spider.paths[:spider], 'SPIDER')
            @compiled = self.class.cache.fetch(cache_path, self) do
                doc = open(path){ |f| Hpricot.XML(f) }
                root_block = TemplateBlocks.parse_element(doc.root, self.class.allowed_blocks)
                root_block.compile
            end
            @cache_path = self.class.cache.get_location(cache_path)
            # Spider.logger.debug("COMPILED:")
            # Spider.logger.debug(@compiled)
        end
        
        def add_widget(id, widget, request=nil, scene=nil, params=nil, content=nil)
            @widgets[id.to_sym] ||= widget
            widget.request = request if request
            widget.scene = scene if scene
            widget.params = params if params
            widget.parse_content_xml(content) if content
        end
        
        def init(request, scene)
            debug("Template init")
            instance_eval(@compiled.init_code, @cache_path+'/init.rb')
        end
        
        
        def prepare
        end
        
        def render(scene=nil)
            scene ||= (@scene || Scene.new)
            debug("Template rendering with scene:")
            debug(scene)            
            scene = Scene.new(scene) if scene.class == Hash
            scene.instance_eval(@compiled.run_code, @cache_path+'/run.rb')
            debug("Template rendered")
        end
        

        def inspect
            self.class.to_s
        end
        
    end
    
    class TemplateCompileError < RuntimeError
    end
    
end