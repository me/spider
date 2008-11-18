require 'spiderfw/controller/controller'
require 'spiderfw/templates/template'

module Spider
    
    class Widget < Controller
        attr_accessor :request, :scene, :params
        
        class << self
            
            def register_tag(name)
                Spider::Template.register(name, self)
            end
            
            def scene_elements(*list)
                @scene_elements ||= []
                @scene_elements += list
            end
            
            def get_scene_elements
                @scene_elements
            end
            
            def default_action
                'run'
            end
            
            def app
                @app ||= self.parent_module
            end
            
            def template_path
                Spider::Logger.debug("Calling template_path")
                app.path+'/widgets/'+Inflector.underscore(self.to_s.split('::')[-1])
            end
            
        end
        
        def initialize
            @scene = Scene.new
            # @env = env
            # @scene = scene || Scene.new
            # @params = params
            init
        end
        
        def init
        end
        
        def render(path=nil, scene=nil)
            scene ||= @scene
            debug("WIDGET RENDERING, SCENE:")
            debug(scene)
            self.class.scene_elements.each do |element|
                scene[element] = instance_variable_get("@#{element}")
            end
            super(path, scene)
        end
                
        def try_rescue(exc)
            if (exc.is_a?(NotFoundException))
                error("Widget path not found: #{exc.path}")
            else
                raise exc
            end
        end
        
        def parse_content_xml(xml)
            parse_content(Hpricot('<content>'+xml+'</content>'))
        end
        
    end
    
end