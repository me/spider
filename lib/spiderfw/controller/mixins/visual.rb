require 'spiderfw/templates/template'
require 'spiderfw/templates/layout'

module Spider; module ControllerMixins
    
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
        
        def load_template(path)
            template = self.class.load_template(path)
            return template
        end 
        
        def render_layout(path, content={})
            layout = self.class.load_layout(path)
            layout.render(content)
        end
        
        def render(path=nil, options={})
            scene = options[:scene] || @scene
            scene ||= get_scene
            scene = prepare_scene(scene)
            request = options[:request] || @request
            response = options[:response] || @response
            template = load_template(path)
            template.request = request
            template.response = response
            template.init(scene)
            template.init_sub
            unless (@_partial_render) # TODO: implement or remove
                chosen_layout = options[:layout] || @layout
                if (chosen_layout)
                    l = chosen_layout.is_a?(Layout) ? chosen_layout : self.class.load_layout(chosen_layout)
                    l.template = template
                    l.render(scene)
                else
                    template.render(scene)
                end
            end
            return template
        end
        
        
        def dispatched_object(route)
            obj = super
            if (obj.is_a?(Visual))
                set_layout = @layout || @dispatcher_layout
                obj.dispatcher_layout = self.class.load_layout(set_layout) if set_layout
            end
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
            
            def load_template(path)
                # TODO: check multiple paths, multiple extensions
                unless respond_to?(:template_path)
                    raise NotImplementedError, "The template_path class method must be implemented by object using the Visual mixin, but #{self} does not"
                end
                t = Spider::Template.new(template_path+'/'+path+'.shtml')
                t.request = @request
                t.response = @response
                return t
            end
            
            def load_layout(path)
                unless respond_to?(:layout_path)
                    raise NotImplementedError, "The layout_path class method must be implemented by object using the Visual mixin, but #{self} does not"
                end
                return Spider::Layout.new(layout_path+'/'+path+'.shtml')
            end
            
            
            def current_default_template
                Spider::Inflector.underscore(self.to_s.split('::')[-1])
            end
            
        end
        
    end
    
    
end; end