module Spider

    class PageController < Controller
        include ControllerMixins::Visual

        def initialize(request, response, scene=nil)
            super
            @widgets = {}
            @scene.request = {
                :path => request.path
            }
        end
        
        
        def get_route(path)
            if (path =~ /^[^:]+:([^:\/]+)[:\/]?(.*)$/) # route to widgets
                if (@widgets[$1])
                    return Route.new(:path => path, :dest => @widgets[$1], :action => $2)
                end
            end
            return super
        end
        
        def load_template(path)
            template = super
            template.widgets = @widgets
            return template
        end
        
        def render(path=nil, scene=nil)
            scene ||= @scene
            scene[:widgets] = @widgets
            super(path, scene)
        end
        
        def param_name(widget_or_id_path)
            id_path = widget_or_id_path.is_a?(Widget) ? widget_or_id_path.id_path : widget_or_id_path
            pre = id_path.map{ |part| "[#{part}]"}.join('')
        end
        
        def params_for(widget_or_id_path, params)
            pre = param_name(widget_or_id_path)
            params.map{ |k, v| "#{pre}[#{k}]=#{v}"}.join('&')
        end
            


    end


end