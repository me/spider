require 'spiderfw/templates/visual'

module Spider
    
    class Widget
        include Visual
        
        class << self
            
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
        
    end
    
end