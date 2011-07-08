module Spider; module Helpers
    
    module WidgetHelper
        
        def self.included(controller)
            controller.extend(ClassMethods)
        end
        
        def prepare_scene(scene)
            scene = super
            if (self.is_a?(Widget))
                scene.widget = widget_to_scene(self)
                scene.widget[:shown_id] = attributes[:keep_id] ? self.local_id : self.full_id
            end
            scene.widgets = {}
            if (@widgets)
                @widgets.each do |id, w|
                    scene.widgets[id] = widget_to_scene(w)
                end
            end
            return scene
        end
        
        def widget_to_scene(w)
            {
                :id_path => w.id_path,
                :full_id => w.full_id,
                :param => param_name(w),
                :param_u => param_name(w, true),
                :pub_path => w.class.pub_url,
                :css_class => w.css_class,
                :css_classes => w.css_classes.uniq.join(' ')
            }
        end
        
        def get_scene(scene=nil)
            scene = super(scene)
            scene.extend(SceneMethods)
            return scene
        end
        
        
        module ClassMethods
            
            def route_widgets(route_name='')
                route 'widgets', :serve_widgets
            end
            
        end
        
        module SceneMethods
        
            def param_name(widget_desc, urlencode=false)
                if (widget_desc.is_a?(Widget))
                    id_path = widget_desc.id_path
                elsif (widget_desc.is_a?(Hash))
                    id_path = widget_desc[:id_path]
                else
                    id_path = widget_desc
                end
                open = urlencode ? '%5B' : '['
                close = urlencode ? '%5D' : ']'
                pre = id_path.map{ |part| "#{open}#{part}#{close}"}.join('')
            end
        
            def params_for(widget_or_id_path, params)
                pre = param_name(widget_or_id_path)
                params.map{ |k, v| "#{pre}[#{k}]=#{v}"}.join('&')
            end
            
        end
        include SceneMethods # FIXME
        
        
    end
    
end; end
