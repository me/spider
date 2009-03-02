require 'spiderfw/templates/template'
require 'spiderfw/templates/layout'

module Spider
    
    # Mixin for objects using templates
    module Visual
        attr_accessor :layout, :dispatcher_layout
        
        def self.included(klass)
           klass.extend(ClassMethods)
        end
        
        def before(action, *params)
            @layout ||= self.class.get_layout(action)
            @layout ||= @dispatcher_layout
            super
        end
        
        def init_template(path)
            template = self.class.init_template(path)
            return template
        end
        
        # def init_template(path=nil)
        #     path ||= self.class.current_default_template
        #     template = init_template(path)
        #     template.init(@request, @scene)
        #     return template
        # end
            
        
        def render_layout(path, content={})
            layout = self.class.init_layout(path)
            layout.render(content)
        end
        
        def render(path=nil, scene=nil, options={})
            scene ||= @scene
            template = init_template(path)
            chosen_layout = options[:layout] || @layout
            if (@layout)
                l = @layout.is_a?(Layout) ? @layout : self.class.init_layout(@layout)
                l.template = template
                l.render(scene)
            else
                template.render(scene)
            end
        end
        
        
        def dispatched_object(route)
            obj = super
            set_layout = @layout || @dispatcher_layout
            obj.dispatcher_layout = self.class.init_layout(set_layout) if set_layout
            return obj
        end
        

            
            
        
        module ClassMethods

            
            def layouts
                @layouts ||= []
            end
            
            def layout(name, params={})
                @layouts ||= []
                @layouts << [name, params]
            end
            
            
            def no_layout(check)
                @no_layout ||= []
                @no_layout << check
            end
            
            def get_layout(action)
                if (@no_layout)
                    @no_layout.each do |check|
                        return nil if check_action(action, check)
                    end
                end
                action = (action && !action.empty?) ? action.to_sym : self.default_action
                layouts.each do |try|
                    name, params = try
                    if (params[:for])
                        next unless check_action(action, params[:for])
                    end
                    if (params[:except])
                        next if check_action(action, params[:except])
                    end
                    return name
                end
                return nil
            end
            
            def init_template(path)
                unless respond_to?(:template_path)
                    raise NotImplementedError, "The template_path class method must be implemented by object using the Visual mixin, but #{self} does not"
                end
                return Spider::Template.new(template_path+'/'+path+'.shtml')
            end
            
            def init_layout(path, scene={})
                unless respond_to?(:layout_path)
                    raise NotImplementedError, "The layout_path class method must be implemented by object using the Visual mixin, but #{self} does not"
                end
                return Spider::Layout.new(layout_path+'/'+path+'.shtml', scene)
            end
            
            
            def current_default_template
                Spider::Inflector.underscore(self.to_s.split('::')[-1])
            end
            
        end
        
    end
    
    
end