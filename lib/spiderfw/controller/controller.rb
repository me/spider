require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/environment'
require 'spiderfw/controller/response'
require 'spiderfw/controller/scene'
require 'spiderfw/templates/visual'
require 'spiderfw/controller/controller_exceptions'
require 'spiderfw/widget/widget'

module Spider
    
    class Controller
        include Dispatcher
        include Visual
        include Logger
        
        class << self

            def default_action
                'index'
            end
            
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
        
        def initialize(env, response, scene=nil)
            @env = env
            @response = response
            @scene = scene || Scene.new
            #@parent = parent
        end
        
        def inspect
            self.class.to_s
        end
        
        def execute(action='', *arguments)
            debug("Controller #{self} executing #{action}")
            @call_path = action
            before(action, *arguments)
            begin
                action = self.class.default_action if (action == '')
                method = action
                method = $1 if (method =~ /^([^:]+)(:.+)$/)
                if (self.class.method_defined?(method.to_sym))
                    layout = self.class.get_layout(method)
                    if (layout) 
                        debug("Execute got layout:")
                        debug(layout)
                        layout = layout.render_and_yield(self, method.to_sym, arguments)
                    else 
                        send(action, *arguments)
                    end
                elsif (can_dispatch?(:execute, action))
                    run_chain(:execute, action, *arguments)
                    dispatch(:execute, action, *arguments)
                    debug("Dispatched by #{self} ")
                    debug("Response is now:")
                    debug(@response)
                    after(action, *arguments)
                else
                    raise NotFoundException.new(action)
                end
            rescue => exc
                try_rescue(exc)
            end
        end

        
        protected

        def dispatched_object(route)
            klass = route.dest
            return klass if klass.class != Class
            klass.new(@env, @response, @scene)
        end
        
        def before(action='', *arguments)
            begin
                run_chain(:before)
                #return dispatch(:before, action, *arguments)
            rescue => exc
                try_rescue(exc)
            end
        end
                

        
        def after(action='', *params)
            begin
                run_chain(:after)
                #dispatch(:after, action, params)
            rescue => exc
                try_rescue(exc)
            end
        end

        
        def try_rescue(exc)
            raise exc
        end
        
        
        private
        
        def pass
            action = @call_path
            return false unless can_dispatch?(:execute, action)
            debug("CAN DISPATCH #{action}")
            dispatch(:execute, action)
            return true
        end

        
    end
    
    
end

