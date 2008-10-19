require 'hpricot'
require 'spiderfw/templates/template_blocks'


module Spider
    
    class Template
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
        
        
        def prepare
        end
        
        def render
        end
        
        def render(scene=nil)
            Spider.logger.debug("RENDERING:")
            Spider.logger.debug(@compiled.run_code)
            scene ||= (@scene || Scene.new)
            scene = Scene.new(scene) if scene.class == Hash
            scene.instance_eval(@compiled.run_code)
        end
        

        
    end
    
end