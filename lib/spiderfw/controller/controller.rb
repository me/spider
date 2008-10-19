require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/environment'
require 'spiderfw/controller/response'
require 'spiderfw/controller/scene'
require 'spiderfw/templates/visual'
require 'spiderfw/widget/widget'
require 'spiderfw/controller/controller_exceptions'

module Spider
    
    class Controller
        include Dispatcher
        include Visual
        
        class << self
            @routes = []
            @layouts = nil
            
            def app
                @app ||= self.parent_module(2)
            end
            
            def template_path
                return self.app.path+'/templates'
            end
            
            def layout_path
                return self.app.path+'/layouts'
            end            
            
        end
        
        attr_reader :env, :response
        attr_reader :action
        
        def initialize(env, response, scene)
            @env = env
            @response = response
            @scene = scene || Scene.new
            #@parent = parent
        end

        
        def dispatched_object(route)
            klass = route.dest
            return klass if klass.class != Class
            klass.new(@env, @response, @scene)
        end
        
        def before(action='', *arguments)
            begin
                run_chain(:before)
                raise NotFoundException.new(action) unless 
                    (can_dispatch?(:execute, action) || (action.to_s.length > 0 && respond_to?(action)))
                return dispatch(:before, action, *arguments)
            rescue => exc
                try_rescue(exc)
            end
        end
                
        def execute(action='', *arguments)
            begin
                action = 'index' if (action == '')
                if (self.class.method_defined?(action.to_sym))
                    layout = self.class.get_layout(action)
                    if (layout) 
                        Spider.logger.debug("Execute got layout:")
                        Spider.logger.debug(layout)
                        layout = layout.render_and_yield(self, action.to_sym, arguments)
                    else 
                        send(action, *arguments)
                    end
                else
                    run_chain(:execute, action, *arguments)
                    dispatch(:execute, action, *arguments)
                end
            rescue => exc
                try_rescue(exc)
            end
        end
        
        def after(action='', *params)
            begin
                run_chain(:after)
                dispatch(:after, action, params)
            rescue => exc
                try_rescue(exc)
            end
        end
        
        def try_rescue(exc)
            raise exc
        end

        
    end
    
    
end