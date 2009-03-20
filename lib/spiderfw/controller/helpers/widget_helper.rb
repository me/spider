module Spider; module Helpers
    
    module WidgetHelper
        
        def prepare_scene(scene)
            scene = super
            if (self.is_a?(Widget))
                scene.widget = widget_to_hash(self)
            end
            scene.widgets = {}
            if (@widgets)
                @widgets.each do |id, w|
                    scene.widgets[id] = widget_to_hash(w)
                end
            end
            return scene
        end
        
        def widget_to_hash(w)
            {
                :id_path => w.id_path,
                :full_id => w.full_id,
                :param => param_name(w),
                :pub_path => w.class.pub_url,
                :css_class => w.css_class || Inflector.underscore(w.class.name).gsub('_', '-').gsub('/', ' ')
            }
        end
        
        def get_scene(scene=nil)
            scene = super(scene)
            scene.extend(SceneMethods)
            return scene
        end
        
        module SceneMethods

        
            def param_name(widget_desc)
                if (widget_desc.is_a?(Widget))
                    id_path = widget_desc.id_path
                elsif (widget_desc.is_a?(Hash))
                    id_path = widget_desc[:id_path]
                else
                    id_path = widget_desc
                end
                pre = id_path.map{ |part| "[#{part}]"}.join('')
            end
        
            def params_for(widget_or_id_path, params)
                pre = param_name(widget_or_id_path)
                params.map{ |k, v| "#{pre}[#{k}]=#{v}"}.join('&')
            end
            
        end
        include SceneMethods # FIXME
        
        
    end
    
end; end