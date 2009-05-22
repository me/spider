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
            template.owner = self
            template.request = request
            template.response = response
            return template
        end
        
        def template_exists?(name)
            self.class.template_exists?(name)
        end
        
        
        def init_template(path, scene=nil, options={})
            scene ||= @scene
            scene ||= get_scene
            template = load_template(path)
            template.init(scene)
            return template
        end
        
        def render_layout(path, content={})
            layout = self.class.load_layout(path)
            layout.request = @request
            layout.render(content)
        end
        
        def init_layout(layout)
            l = layout.is_a?(Layout) ? layout : self.class.load_layout(layout)
            l.owner = self
            l.request = request
            return l
        end
        
        def render(path=nil, options={})
            scene = options[:scene] || @scene
            scene ||= get_scene
            scene = prepare_scene(scene)
            request = options[:request] || @request
            response = options[:response] || @response
            template = init_template(path, scene, options)
            template._action_to = options[:action_to]
            template._action = @action
            template.exec
            unless (@_partial_render) # TODO: implement or remove
                chosen_layout = options[:layout] || @layout
                if (chosen_layout)
                    l = init_layout(chosen_layout)
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
            
            def template_paths
                unless respond_to?(:template_path)
                    raise NotImplementedError, "The template_path class method must be implemented by object using the Visual mixin, but #{self} does not"
                end
                paths = [template_path]
                s = self.superclass
                while (s && s.subclass_of?(Visual) && s.app && s.respond_to?(:template_path))
                    paths << s.template_path
                    s = s.superclass
                end
                return paths
            end
                
            
            def load_template(name)
                # TODO: check multiple paths, multiple extensions
                if (name[0..5] == 'SPIDER' || name[0..3] == 'ROOT')
                    name.sub!('SPIDER', $SPIDER_PATH).sub!('ROOT', Spider.paths[:root])
                    t = Spider::Template.new(name+'.shtml')
                else
                    template_paths.each do |path|
                        full = path+'/'+name+'.shtml'
                        next unless File.exist?(full)
                        t = Spider::Template.new(full)
                        break
                    end
                end
                if (t)
                    t.request = @request
                    t.response = @response
                    return t
                end
                raise "Template #{name} not found"
            end
            
            def template_exists?(name, paths=nil)
                if (name[0..5] == 'SPIDER' || name[0..3] == 'ROOT')
                    name.sub!('SPIDER', $SPIDER_PATH).sub!('ROOT', Spider.paths[:root])
                    return true if File.exist?(name)
                end
                paths ||= template_paths
                paths.each do |path|
                    full = path+'/'+name+'.shtml'
                    return true if File.exist?(full)
                end
                return false
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