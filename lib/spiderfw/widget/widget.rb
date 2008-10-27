require 'spiderfw/controller/controller'

module Spider
    
    class Widget < Controller
        
        class << self
            
            def default_action
                'run'
            end
            
            def app
                @app ||= self.parent_module
            end
            
            def template_path
                app.path+'/widgets/'+Inflector.underscore(self.to_s.split('::')[-1])
            end
            
        end
        
        def initialize(env, scene, params)
            @env = env
            @scene = scene || Scene.new
            @params = params
        end
        
        def try_rescue(exc)
            if (exc.is_a?(NotFoundException))
                error("Widget path not found: #{exc.path}")
            else
                raise exc
            end
        end
        
    end
    
end