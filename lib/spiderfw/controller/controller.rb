require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/request'
require 'spiderfw/controller/response'
require 'spiderfw/controller/scene'
require 'spiderfw/controller/controller_exceptions'
require 'spiderfw/controller/first_responder'

require 'spiderfw/controller/mixins/visual'
require 'spiderfw/controller/mixins/http_mixin'
require 'spiderfw/controller/mixins/static_content'

require 'spiderfw/controller/helpers/widget_helper'

module Spider
    
    class Controller
        include Dispatcher
        include Logger
        include ControllerMixins
        include Helpers
        
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
            
            def check_action(action, check)
                checks = check.is_a?(Array) ? check : [check]
                action = action.to_s
                action = default_action if action == ''
                action = action[0..-1] if action[-1].chr == '/'
                checks.each do |check|
                    return true if check.is_a?(String) && action == check || (action[-1].chr == '/' && action[0..-2] == check)
                    return true if check.is_a?(Regexp) && action =~ check
                end
                return false
            end
            
        end
        
        attr_reader :request, :response, :executed_method
        attr_accessor :dispatch_action
        
        def initialize(request, response, scene=nil)
            @request = request
            @response = response
            @scene = scene || get_scene
            @dispatch_path = ''
            init
            #@parent = parent
        end
        
        # Override this for controller initialization
        def init
            
        end
        
        def inspect
            self.class.to_s
        end
        
        def call_path
            act = @dispatch_action || ''
            if (@dispatch_previous)
                prev = @dispatch_previous.call_path 
                act = prev+'/'+act unless prev.empty?
            end
            return ('/'+act).gsub(/\/+/, '/')
        end
        
        def request_path
            call_path
        end
        
        
        def execute(action='', *arguments)
            return if @done
            debug("Controller #{self} executing #{action} with arguments #{arguments}")
            @call_path = action
            # before(action, *arguments)
            # do_dispatch(:before, action, *arguments)
            catch(:done) do
                method = action.empty? ? self.class.default_action : action
                method = method.split('/', 2)[0]
                additional_arguments = []
                if (action =~ /^([^:]+)(:.+)$/)
                    method = $1
                elsif (action =~ /^([^\/]+)\/(.+)$/) # methods followed by a slash
                    method = $1
                    additional_arguments = [$2]
                end
                if (can_dispatch?(:execute, action))
                    #run_chain(:execute, action, *arguments)
                    do_dispatch(:execute, action)
#                        after(action, *arguments)
                elsif (self.class.method_defined?(method.to_sym))
                    meth = self.method(method.to_sym)
                    args = meth.arity == 0 ? [] : (arguments+additional_arguments)[0..meth.arity]
                    args = [nil] if meth.arity == 1 && args.empty?
                    @action = args[0]
                    @executed_method = method.to_s
                    send(method, *args)
                else
                    raise NotFound.new(action)
                end
            end   
        end
        
        def before(action='', *arguments)
            catch(:done) do
                debug("#{self} before")
                do_dispatch(:before, action, *arguments)
            end
        end
                

        
        def after(action='', *arguments)
            catch(:done) do
                do_dispatch(:after, action, *arguments)
            end
            # begin
            #     run_chain(:after)
            #     #dispatch(:after, action, params)
            # rescue => exc
            #     try_rescue(exc)
            # end
        end
        
        def done
            self.done = true
            throw :done
        end
        
        def done=(val)
            @done = val
            @dispatch_previous.done = val if @dispatch_previous
        end
        
        def get_scene(scene=nil)
            scene = Scene.new(scene) if scene.class == Hash
            scene ||= Scene.new
            # debugger
            # scene.extend(SceneMethods)
            return scene
        end
        
        def prepare_scene(scene)
            scene.request = {
                :path => @request.path
            }
            scene.controller = {
                :request_path => request_path
            }
            return scene
        end

        protected

        def dispatched_object(route)
            klass = route.dest
            return klass if klass.class != Class
            obj = klass.new(@request, @response, @scene)
            obj.dispatch_action = route.matched || ''
#            obj.dispatch_path = @dispatch_path + route.path
            return obj
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
        
        module SceneMethods
        end


    end
    
    
end

require 'spiderfw/widget/widget'
