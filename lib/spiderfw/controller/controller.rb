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

require 'spiderfw/utils/annotations'

module Spider
    
    class Controller
        include Dispatcher
        include Logger
        include ControllerMixins
        include Helpers
        include Annotations
        
        class << self
            
            def options
                @options ||= {}
            end
            
            def option(k, v)
                self.option[k] = v
            end

            def default_action
                'index'
            end
            
            def app
                return @app if @app
                @app ||= self.parent_module
                @app = nil unless self.parent_module.include?(Spider::App)
                return @app
            end
            
            def template_path
                return nil unless self.app
                return self.app.path+'/views'
            end
            
            def layout_path
                return nil unless self.app
                return self.app.path+'/views'
            end
        
            # Defines a method that will be called before the controller's before,
            # if the action matches the given conditions.
            # - The first argument, the condition(s), may be a String, a Regexp, a Proc or a Symbol,
            # that will be checked against the action, or an Array containing several conditions.
            # - The second argument, a Symbol, is the method to be called if the conditions match.
            # - The third optional argument, an Hash, may contain :unless => true: in this case,
            # the conditions will be inverted, that is, the method will be executed unless the conditions
            # match.
            # Example:
            #   before('list_', :before_lists)
            # will call the method before_lists if the action starts with 'list_'
            def before(conditions, method, params={})
                @dispatch_methods ||= {}
                @dispatch_methods[:before] ||= []
                @dispatch_methods[:before] << [conditions, method, params]
            end
            
            def before_methods
                @dispatch_methods && @dispatch_methods[:before] ? @dispatch_methods[:before] : []
            end
            
            def before_unless(condition, method, params={})
                @dispatch_methods ||= {}
                @dispatch_methods[:before] ||= []
                params[:unless] = true
                @dispatch_methods[:before] << [condition, method, params]
            end
            
            def controller_actions(*methods)
                if (methods.length > 0)
                    @controller_actions ||= []
                    @controller_actions += methods
                end
                @controller_actions
            end
            
            def controller_action?(method)
                return false unless self.method_defined?(method)
                return true if default_action && method == default_action.to_sym
                if @controller_actions
                    res = @controller_actions.include?(method)
                    if (!res)
                        Spider.logger.info("Method #{method} is not a controller action for #{self}")
                    end
                    return res
                else
                    return true
                end
            end
            
            def find_resource(type, name, cur_path=nil)
                Spider.find_resource(type, name, cur_path, self)
            end
            
            def find_resource_path(type, name, cur_path=nil)
                res = Spider.find_resource(type, name, cur_path, self)
                return res ? res.path : nil
            end
            
            def url=(url)
                @url = url
            end
            
            def url
                @url || ''
            end
            
            
        end
        
        define_annotation(:action) { |k, m| k.controller_actions(m) }
        
        attr_reader :request, :response, :executed_method, :scene
        attr_accessor :dispatch_action, :is_target
        
        def initialize(request, response, scene=nil)
            @request = request
            @response = response
            @scene = scene || get_scene
            @dispatch_path = ''
            @is_target = true
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
            return ('/'+act).gsub(/\/+/, '/').sub(/\/$/, '')
        end
        
        def request_path
            call_path
        end
        
        def get_action_method(action)
            method = nil
            additional_arguments = nil
            # method = action.empty? ? self.class.default_action : action
            # method = method.split('/', 2)[0]
            if (action =~ /^([^:]+)(:.+)$/)
                method = $1
            elsif (action =~ /^([^\/]+)\/(.+)$/) # methods followed by a slash
                method = $1
                additional_arguments = [$2]
            else
                method = action
            end
            method = self.class.default_action if !method || method.empty?
            return nil if method.empty?
            return [method.to_sym, additional_arguments]
        end
        
        # Returns true if this controller is the final target for the current action, that is, if it does not
        # dispatch to any route
        def action_target?
            !@dispatch_next[@call_path] || @dispatch_next[@call_path].dest == self
        end
        
        # Returns false if the target of the call is a widget, true otherwise
        def is_target?
            @is_target
        end
        
        
        def execute(action='', *arguments)
            return if @__done
            # return if self.is_a?(Spider::Widget) # FIXME: this is obviously wrong. Widgets must override the behaviour
            # # somewhere else, or probably just not inherit controller.
            debug("Controller #{self} executing #{action} with arguments #{arguments}")
            # before(action, *arguments)
            # do_dispatch(:before, action, *arguments)
            catch(:done) do
                if (can_dispatch?(:execute, action))
                    d_next = dispatch_next(action)
                    #run_chain(:execute, action, *arguments)
                    #  shortcut route to self
                    return do_dispatch(:execute, action) if d_next.dest != self 
                    arguments = d_next.params
                end
                if (@executed_method)
                    meth = self.method(@executed_method)
                    args = arguments + @executed_method_arguments
                    @controller_action = args[0]
                    arity = meth.arity
                    arity = (-arity + 1) if arity < 0
                    args = arity == 0 ? [] : args[0..(arity-1)]
                    args = [nil] if meth.arity == 1 && args.empty?
                    Spider.logger.info("Executing: #{self.class.name}##{@executed_method}.#{@request.format}")
                    send(@executed_method, *args)
                else
                    raise NotFound.new(action)
                end
            end
        end
        
        def before(action='', *arguments)
            @call_path = action
            catch(:done) do
                #debug("#{self} before")
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
        
        def done?
            @__done
        end
        
        def done
            self.done = true
            throw :done
        end
        
        def done=(val)
            @__done = val
            @dispatch_previous.done = val if @dispatch_previous
        end
        
        def check_action(action, c)
            self.class.check_action(action, c)
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
                :request_path => request_path,
                :class => self.class
            }
            scene.content = {}
            return scene
        end

        protected

        def dispatched_object(route)
            klass = route.dest
            if klass.class != Class
                if (klass == self) # route to self
                    @executed_method = route.action.to_sym
                    @executed_method_arguments = []
                end
                return klass
            end
            obj = klass.new(@request, @response, @scene)
            obj.dispatch_action = route.matched || ''
            # FIXME: this is not clean
            obj.set_action(route.action)
#            obj.dispatch_path = @dispatch_path + route.path
            return obj
        end
                
        def set_action(action)
            @executed_method = nil
            @executed_method_arguments = nil
            if (!can_dispatch?(:execute, action))
                method, additional_arguments = get_action_method(action)
                if (method && self.class.controller_action?(method))
                    @executed_method = method.to_sym
                    @executed_method_arguments = additional_arguments || []
                end
            end
        end
        

        def try_rescue(exc)
            raise exc
        end
        
        
        private
        
        def pass
            action = @call_path
            return false unless can_dispatch?(:execute, action)
            #debug("CAN DISPATCH #{action}")
            do_dispatch(:execute, action)
            return true
        end
        
        module SceneMethods
        end


    end
    
    
end

require 'spiderfw/widget/widget'
require 'spiderfw/tag/tag'
