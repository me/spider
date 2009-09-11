require 'spiderfw/controller/controller'

module Spider

    class PageController < Controller
        include Visual
        include WidgetHelper
        include HTTPMixin
        include StaticContent

        def initialize(request, response, scene=nil)
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
        
        def load_template(path)
            template = super
            template.widgets = @widgets
            return template
        end
        # 
        # def render(path=nil, scene=nil)
        #     scene ||= @scene
        #     scene[:widgets] = @widgets
        #     super(path, scene)
        # end
        # 



    end


end