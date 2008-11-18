require 'spiderfw/templates/template'
require 'spiderfw/templates/layout'

module Spider
    
    # Mixin for objects using templates
    module Visual
        
        def self.included(klass)
           klass.extend(ClassMethods)
        end
        
        def load_template(path)
            template = self.class.load_template(path)
            return template
        end
        
        def init_template(path=nil)
            path ||= self.class.current_default_template
            template = load_template(path)
            template.init(@request, @scene)
            return template
        end
            
        
        def render_layout(path, content={})
            layout = self.class.load_layout(path)
            layout.render(content)
        end
        
        def render(path=nil, scene=nil)
            template = init_template(path)
            template.render(scene || @scene)
        end
        
        module ClassMethods
            
            def layout(name, params={})
                @layouts ||= []
                @layouts << [name, params]
            end
            
            def template_path
                raise NotImplementedError, "The template_path class method must be implemented by object using the Visual mixin"
            end
            
            def layout_path
                raise NotImplementedError, "The layout_path class method must be implemented by object using the Visual mixin"
            end
            
            def load_template(path)
                return Spider::Template.load(template_path+'/'+path+'.shtml')
            end
            
            def load_layout(path)
                return Spider::Layout.load(layout_path+'/'+path+'.shtml')
            end
            
            def get_layout(action)
                return nil unless @layouts
                action = action.to_sym
                @layouts.each do |try|
                    name, params = try
                    return load_layout(name) # FIXME: check the params
                end
            end
            
            def current_default_template
                Spider::Inflector.underscore(self.to_s.split('::')[-1])
            end
            
        end
        
    end
    
    
end