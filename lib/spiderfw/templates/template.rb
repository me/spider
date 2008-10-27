require 'hpricot'
require 'spiderfw/templates/template_blocks'


module Spider
    
    class Template
        include Logger
        
        attr_accessor :widgets
        
        @@registered = {}
        
        class << self
        
            def allow_blocks(*tags)
                @allowed_blocks = tags
            end

            def allowed_blocks
                @allowed_blocks
            end

            def load(path, scene={})
                return nil unless File.exist?(path)
                p = self.new(scene)
                p.load(path)
                return p
            end
            
            def register(tag, symbol)
                @@registered[tag] = symbol
            end
            
            def registered
                @@registered
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
            doc = open(path){ |f| Hpricot.XML(f) }
            @root_block = TemplateBlocks.parse_element(doc.root, self.class.allowed_blocks)
            @compiled = @root_block.compile
            # Spider.logger.debug("COMPILED:")
            # Spider.logger.debug(@compiled)
        end
        
        def add_widget(id, widget)
            @widgets[id] ||= widget
        end
        
        def init(env, scene)
            debug("INIT:")
            debug(@compiled.init_code)
            instance_eval(@compiled.init_code)
        end
        
        
        def prepare
        end
        
        def render
        end
        
        def render(scene=nil)
            debug("RENDERING:")
            debug(@compiled.run_code)
            scene ||= (@scene || Scene.new)
            scene = Scene.new(scene) if scene.class == Hash
            scene.instance_eval(@compiled.run_code)
        end
        

        def inspect
            self.class.to_s
        end
        
    end
    
end