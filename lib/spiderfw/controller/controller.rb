require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/request'
require 'spiderfw/controller/response'
require 'spiderfw/controller/scene'
require 'spiderfw/templates/visual'
require 'spiderfw/controller/controller_exceptions'
require 'spiderfw/widget/widget'

require 'spiderfw/controller/helpers/http'

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
                @app ||= self.parent_module
            end
            
            def template_path
                return self.app.path+'/templates'
            end
            
            def layout_path
                return self.app.path+'/layouts'
            end            
            
        end
        
        attr_reader :request, :response
        attr_reader :action
        
        def initialize(request, response, scene=nil)
            @request = request
            @response = response
            @scene = scene || Scene.new
            init
            #@parent = parent
        end
        
        # Override this for controller initialization
        def init
            
        end
        
        def inspect
            self.class.to_s
        end
        
        def execute(action='', *arguments)
            return if @done
            debug("Controller #{self} executing #{action} with arguments")
            debug(arguments)
            @call_path = action
            # before(action, *arguments)
            # do_dispatch(:before, action, *arguments)
            catch(:done) do
                begin
                    action = self.class.default_action if (action == '')
                    method = action
                    additional_arguments = []
                    if (action =~ /^([^:]+)(:.+)$/)
                        method = $1
                    elsif (action =~ /^([^\/]+)\/(.+)$/) # methods followed by a slash
                        method = $1
                        additional_arguments = [$2]
                    end
                    layout = self.class.get_layout(method) # FIXME! move to visual somehow
                    if (self.class.method_defined?(method.to_sym))
                   
                        if (layout) 
                            layout = layout.render_and_yield(self, method.to_sym, arguments)
                        else
                            send(method, *(arguments+additional_arguments))
                        end
                    elsif (can_dispatch?(:execute, action))
                        #run_chain(:execute, action, *arguments)
                        if (layout)
                            obj, route_method, new_arguments = dispatch(:execute, action)
                            new_arguments.unshift(route_method)
                            layout = layout.render_and_yield(obj, :execute, new_arguments)
                        else
                            do_dispatch(:execute, action)
                        end
                        after(action, *arguments)
                    else
                        raise NotFoundException.new(action)
                    end
                rescue => exc
                    try_rescue(exc)
                end
            end
        end
        
        def before(action='', *arguments)
            catch(:done) do
                debug("IN BEFORE; I AM #{self}")
                # begin
                #     run_chain(:before)
                #     #return dispatch(:before, action, *arguments)
                # rescue => exc
                #     try_rescue(exc)
                # end
                do_dispatch(:before, action, *arguments)
            end
        end
                

        
        def after(action='', *arguments)
            do_dispatch(:after, action, *arguments)
            # begin
            #     run_chain(:after)
            #     #dispatch(:after, action, params)
            # rescue => exc
            #     try_rescue(exc)
            # end
        end
        
        def done
            @done = true
            throw :done
        end

        
        protected

        def dispatched_object(route)
            klass = route.dest
            return klass if klass.class != Class
            klass.new(@request, @response, @scene)
        end
        


        
        def try_rescue(exc)
            raise exc
        end
        
        
        private
        
        def pass
            action = @call_path
            return false unless can_dispatch?(:execute, action)
            debug("CAN DISPATCH #{action}")
            do_dispatch(:execute, action)
            return true
        end

        
    end
    
    
end

