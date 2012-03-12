require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/request'
require 'spiderfw/controller/response'
require 'spiderfw/controller/scene'
require 'spiderfw/controller/controller_exceptions'
require 'spiderfw/controller/first_responder'

require 'spiderfw/controller/controller_mixin'

require 'spiderfw/controller/mixins/visual'
require 'spiderfw/controller/mixins/http_mixin'
require 'spiderfw/controller/mixins/static_content'

require 'spiderfw/controller/helpers/widget_helper'

require 'spiderfw/utils/annotations'

module Spider
    
    class Controller
        include App::AppClass
        include Dispatcher
        include Logger
        include ControllerMixins
        include Helpers
        include Annotations
        
        class << self

            def default_action
                'index'
            end
            
            # @return [String] Path to this controller's templates
            def template_path
                return nil unless self.app
                return File.join(self.app.path, '/views')
            end
            
            # @return [String] Path to this controller's layouts
            def layout_path
                return nil unless self.app
                return File.join(self.app.path, '/views')
            end
        
            # Defines a method that will be called before the controller's before,
            # if the action matches the given conditions.
            # Example:
            #   before(/^list_/, :before_lists)
            # will call the method before_lists if the action starts with 'list_'
            # @param [String|Regexp|Proc|Symbol|Array] conditions what will be checked against the action
            # @param [Symbol] method The method to be called if the conditions match.
            # @param [Hash] params may contain :unless => true: in this case,
            #               the conditions will be inverted, that is, the method will 
            #               be executed unless the conditions match.
            # @return [void]
            def before(conditions, method, params={})
                @dispatch_methods ||= {}
                @dispatch_methods[:before] ||= []
                @dispatch_methods[:before] << [conditions, method, params]
            end

            # Like {Controller.before}, but calls the method unless the conditions match
            # @param [String|Regexp|Proc|Symbol|Array] conditions what will be checked against the action
            # @param [Symbol] method The method to be called if the conditions match.
            # @param [Hash] params may contain :unless => true: in this case,
            #               the conditions will be inverted, that is, the method will 
            #               be executed unless the conditions match.
            # @return [void]
            def before_unless(condition, method, params={})
                @dispatch_methods ||= {}
                @dispatch_methods[:before] ||= []
                params[:unless] = true
                @dispatch_methods[:before] << [condition, method, params]
            end
            
            # @return [Array] An array of methods defined with {Controller.before}
            def before_methods
                @dispatch_methods && @dispatch_methods[:before] ? @dispatch_methods[:before] : []
            end
            
            # Registers a list of methods as controller actions, that is, methods that can
            # be dispatched to. 
            # 
            # This method is not usually called directly; using the __.action annotation,
            # or one of the format annotations (__.html, __.xml, __.json, __.text), will
            # make a method a controller action.
            # @param [*Symbol] A list of methods
            # @return [Array] All defined controller actions
            def controller_actions(*methods)
                if (methods.length > 0)
                    @controller_actions ||= []
                    @controller_actions += methods
                end
                @controller_actions
            end

            def controller_action(method, params)
                @controller_actions ||= []
                @controller_actions << method
                @controller_action_params ||= {}
                @controller_action_params[method] = params
            end
            
            # @return [bool] true if the method is a controller action
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
            
            # Finds a resource in the context of the controller's app
            # See {Spider.find_resource}
            # @param [Symbol] resource_type
            # @param [String] path
            # @param [String] cur_path Current path: if set, will be used to resolve relative paths
            # @return [Resource]
            def find_resource(type, name, cur_path=nil)
                Spider.find_resource(type, name, cur_path, self)
            end
            
            # Returns the path of a resource, or nil if none is found
            # See {Controller.find_resource}
            # @param [Symbol] resource_type
            # @param [String] path
            # @param [String] cur_path Current path: if set, will be used to resolve relative paths
            # @return [Resource]
            def find_resource_path(type, name, cur_path=nil)
                res = Spider.find_resource(type, name, cur_path, self)
                return res ? res.path : nil
            end
            
            # @param [String] action Additional action to get path for
            # @return [String] The canonical URL path for this controller
            def route_path(action=nil)
                u = @default_route || ''
                u += "/#{action}" if action
                if @default_dispatcher && @default_dispatcher != self
                    u = @default_dispatcher.route_path(u)
                elsif self.app
                    u = self.app.route_path(u)
                end
                u
            end

            # Returns the full URL for the Controller
            # The Controller's implementation returns the route_path.
            #
            # However, the HTTPMixin will override this method to return a full http url;
            # other mixins can override the method in different ways.
            # @param [String] action Additional action to get path for
            # @return [String] The canonical URL for this controller
            def url(action=nil)
                route_path(action)
            end
            alias :route_url :url
            
            
        end
        
        define_annotation(:action) { |k, m, params| k.controller_action(m, params) }
        
        # @return [Spider::Request]
        attr_reader :request
        # @return [Spider::Response]
        attr_reader :response
        # @return [Symbol] The method currently set to be executed, if any
        attr_reader :executed_method
        # @return [Scene]
        attr_reader :scene
        # @return [String] Action used to reach this controller in the dispatch chain
        attr_accessor :dispatch_action
        # @return [bool] True if the controller is the target of the current action
        attr_accessor :is_target
        
        # Constructor. Note: you can use the {Controller#init} method for custom
        # initialization, instead of overrideing this method
        # @param [Spider::Request] request
        # @param [Spider::Response] response
        # @param [scene]
        def initialize(request, response, scene=nil)
            @request = request
            @response = response
            @scene = scene || get_scene
            @dispatch_path = ''
            @is_target = true
            init
        end
        
        # Override this for controller initialization
        # @return [void]
        def init
        end
        
        # @return [String]
        def inspect
            self.class.to_s
        end
        
        # @return [String] The actual action path used to reach this Controller
        def request_path
            act = @dispatch_action || ''
            if (@dispatch_previous)
                prev = @dispatch_previous.call_path 
                act = prev+'/'+act unless prev.empty?
            end
            return ('/'+act).gsub(/\/+/, '/').sub(/\/$/, '')
        end
        alias :call_path :request_path
        
        # Returns the method to call on the controller given an action, and the arguments
        # that should be passed to it.
        # @param [String] action
        # @return [Array] A two elements array, containing the method, and additional arguments
        def get_action_method(action)
            method = nil
            additional_arguments = nil
            if (action =~ /^([^:]+)(:.+)$/)
                method = $1
            elsif (action =~ /^([^\/]+)\/(.+)$/) # methods followed by a slash
                method = $1
                additional_arguments = [$2]
            else
                method = action
            end
            method = method[0..-2] if !method.blank? && method[-1].chr == '/'
            method, rest = method.split('.', 2) if method
            method = self.class.default_action if !method || method.empty?
            return nil if method.empty?
            return [method.to_sym, additional_arguments]
        end
        
        # Returns true if this controller is the final target for the current action, that is, if it does not
        # dispatch to any route
        # @return [bool] True if the controller is the final target
        def action_target?
            !@dispatch_next[@call_path] || @dispatch_next[@call_path].dest == self
        end
        
        # @return [bool] false if the target of the call is a widget, true otherwise
        def is_target?
            @is_target
        end
        
        
        # The main controller's execution method. The Controller will dispatch
        # to another controller if a route is set; otherwise, it will call the 
        # method that should be executed according to action.
        #
        # This method can be overridden in subclasses, but remember to call super,
        # or the dispatch chain will stop!
        # @param [String] action The current action
        # @param [*Object] arguments Additional action arguments
        def execute(action='', *arguments)
            return if @__done
            debug("Controller #{self} executing #{action} with arguments #{arguments}")
            catch(:done) do
                if can_dispatch?(:execute, action)
                    d_next = dispatch_next(action)
                    #run_chain(:execute, action, *arguments)
                    #  shortcut route to self
                    return do_dispatch(:execute, action) if d_next.dest != self 
                    arguments = d_next.params
                end
                if d_next && d_next.dest == self
                    set_executed_method(d_next.action)
                end
                if @executed_method
                    meth = self.method(@executed_method)
                    args = arguments + @executed_method_arguments
                    @controller_action = args[0]
                    arity = meth.arity
                    unless arity == -1
                        arity = (-arity + 1) if arity < 0
                        args = arity == 0 ? [] : args[0..(arity-1)]
                        args = [nil] if meth.arity == 1 && args.empty?
                    end
                    Spider.logger.info("Executing: #{self.class.name}##{@executed_method}.#{@request.format}")
                    spider_main_controller_send = true
                    send(@executed_method, *args)
                else
                    raise NotFound.new(action)
                end
            end
        end
        
        # Helper method, that calls and propagates #before
        # @param [String] action The current action
        # @param [*Object] arguments Additional action arguments
        def call_before(action='', *arguments)
            return if respond_to?(:serving_static?) && self.serving_static?
            @call_path = action
            before(action, *arguments)
            catch(:done) do
                #debug("#{self} before")
                d_next = dispatch_next(action)
                unless d_next && d_next.obj == self
                    do_dispatch(:call_before, action, *arguments)
                end
            end
        end
        
        # This method can be implemented by Controllers, and will be called
        # on the controller chain before the execute method.
        #
        # This method is usually reserved for preprocessing that does not
        # output to the browser, to allow other controllers in chain to set response
        # headers.
        # @param [String] action The current action
        # @param [*Object] arguments Additional action arguments
        def before(action='', *arguments)
        end

        # Helper method, that calls and propagates #after
        # @param [String] action The current action
        # @param [*Object] arguments Additional action arguments
        def call_after(action='', *arguments)
            return if respond_to?(:serving_static?) && self.serving_static?
            after(action, *arguments)
            catch(:done) do
                d_next = dispatch_next(action)
                unless d_next && d_next.obj == self
                    do_dispatch(:call_after, action, *arguments)
                end
            end
        end

        # This method can be implemented by Controllers, and will be called
        # on the controller chain after the execute method.
        #
        # If the webserver supports it, this method will be called after the response
        # has been returned to the browser; so, it's suitable for post processing.
        # If you aren't using a threaded web server, though, keep in mind that the
        # process won't be available to service other requests.
        # @param [String] action The current action
        # @param [*Object] arguments Additional action arguments
        def after(action='', *arguments)
        end
        
        # @return [bool] True if the controller is done, and should not continue dispatching.
        def done?
            @__done
        end
        
        # Stops the execution of the controller chain
        # @return [void]
        def done
            self.done = true
            throw :done
        end
        
        # Sets the controller chain's "done" state
        # @param [bool] val 
        # @return [void]
        def done=(val)
            @__done = val
            @dispatch_previous.done = val if @dispatch_previous
        end
        
        # Checks if an action responds to given route conditions. Is called by 
        # {Dispatcher#do_dispatch}.
        # The default implementation calls Controller.check_action, which in turn is mixed in
        # from {Dispatcher::ClassMethods#check_action}
        # @param [String] action
        # @param [Array] c An array of route conditions
        # @return [bool]
        def check_action(action, c)
            self.class.check_action(action, c)
        end
        
        # Returns a new Scene instance for use in the controller.
        # @param [Hash] scene Hash to construct the scene from
        # @return [Scene] 
        def get_scene(scene=nil)
            scene = Scene.new(scene) if scene.class == Hash
            scene ||= Scene.new
            return scene
        end
        
        # Sets controller information on a scene
        # @param [Scene] scene
        # @return [Scene]
        def prepare_scene(scene)
            req_path = @request.path
            req_path += 'index' if !req_path.blank? && req_path[-1].chr == '/'
            scene.request = {
                :path => @request.path,
                :page_path => req_path
            }
            scene.controller = {
                :request_path => request_path,
                :class => self.class
            }
            scene.content = {}
            return scene
        end

        # See {Controller.controller_action?}
        # @return [bool] True if the method is a controller action for the class
        def controller_action?(method)
            self.class.controller_action?(method)
        end

        protected

        # Instantiates an object dispatched by a route
        # @param [Route]
        # @return [Controller]
        def dispatched_object(route)
            klass = route.dest
            if klass.class != Class
                if klass == self # route to self
                    set_executed_method(route.action)
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
        
        # Given an action, sets the executed method unless it can be dispatched
        # @param [String] action
        # @return [Symbol|nil] The executed method, if it was set, or nil
        def set_action(action)
            @executed_method = nil
            @executed_method_arguments = nil
            if !can_dispatch?(:execute, action)
                return set_executed_method(action)
            end
            nil
        end

        # Given an action, sets executed_method and executed_method_arguments
        # @param [String] action
        # @return [Symbol] The executed_method
        def set_executed_method(action)
            method, additional_arguments = get_action_method(action)
            if (method && controller_action?(method))
                @executed_method = method.to_sym
                @executed_method_arguments = additional_arguments || []
            end
            return @executed_method
        end

        # This method can be overrided by subclasses, to provide custom handling of
        # exceptions
        # @param [Exception]
        # @return [void]
        def try_rescue(exc)
            raise exc
        end

        private

        # Overrides {Dispatcher#get_route}, setting the action for nil routes
        # @param [String] path
        def get_route(*args)
            route = super
            return route unless route
            action = route.path.split('/').first
            action_method, action_params = get_action_method(action)
            if route.nil_route && !action.blank? && self.respond_to?(action_method)
                route.action = action
            end
            route
        end

    end
    
    
end

require 'spiderfw/widget/widget'
require 'spiderfw/tag/tag'
