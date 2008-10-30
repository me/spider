module Spider

    class PageController < Controller

        def initialize(env, response, scene=nil)
            super
            @widgets = {}
        end
        
        def get_route(path)
            if (path =~ /^[^:]+:([^:\/]+)[:\/]?(.*)$/) # route to widgets
                if (@widgets[$1])
                    return Route.new(:path => path, :dest => @widgets[$1], :action => $2)
                end
            end
            return super
        end
        
        def init_template(path)
            template = load_template(path)
            template.widgets = @widgets
            template.init(@env, @scene)
            return template
        end
        
        def render(path=nil, scene=nil)
            scene ||= @scene
            scene[:widgets] = @widgets
            super(path, scene)
        end
            


    end


end