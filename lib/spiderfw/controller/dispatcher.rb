module Spider
    
    # The includer of this module has to define a method dispatched_object, which must
    # return a child object given the class, the next action, and the route parameters
    module Dispatcher
        attr_reader :dispatched_action
        attr_accessor :dispatch_previous
        attr_accessor :action
        
        def self.included(klass)
           klass.extend(ClassMethods)
        end
        
        
        def routes
            @routes ||= []
        end
        
        
        # Adds one or more routes to the dispatcher.
        # Also accepts an Hash containing path/destination couples
        #
        # ==== Parameters
        # path<String, Regexp>:: 
        #   When a string is passed, a path matches if it matches exactly
        #   When a regular expression is passed, it is used to match the path
        # dest<Spider::Controller, Proc>::
        #   The route destination
        def route(path, dest=nil, options=nil)
            @routes ||= []
            self.class.add_route(@routes, path, dest, options)
        end
        
        def dispatch(method, action='', *arguments)
            return nil unless can_dispatch?(method, action)
            @dispatched_action = action
            obj, route = @dispatch_next[action]
            new_arguments = arguments
            new_arguments += route.params unless route.options[:remove_params]
            obj.action = route.action
            return [obj, route.action, new_arguments]
#            return obj.send(method, route.action, *(new_arguments))
        end
        
        def do_dispatch(method, action='', *arguments)
            obj, route_action, new_arguments = dispatch(method, action, *arguments)
            return nil unless obj
            meth_action = route_action.length > 0 ? route_action : obj.class.default_action
            unless meth_action.empty?
                meth_action = meth_action[0..-2] if meth_action[-1].chr == '/'
                try_meth = "#{method}_#{meth_action.downcase}"
                return obj.send(try_meth, *new_arguments) if obj.respond_to?(try_meth)
            end
            return obj.send(method, route_action, *(new_arguments))
        end

        
        def can_dispatch?(method, action)
            d_next = dispatch_next(action)
            return false unless d_next && d_next[0].respond_to?(method)
            return true
        end
                
        def do_route(path)
            next_route = get_route(path)
            return false unless next_route
            obj = dispatched_object(next_route)
            obj.dispatch_previous = self if obj.respond_to?(:dispatch_previous=)
            return [obj, next_route]
        end
        
        def dispatch_next(path)
            @dispatch_next ||= {}
            @dispatch_next[path] ||= do_route(path)
        end
        
        def get_route(path)
            r = routes + self.class.routes
            r.each do |route|
                try, dest, options = route
                action = nil
                case try
                when true
                    action = path
                when String
                    test_path = path
                    if (options[:ignore_case])
                        test_path = path.downcase
                        try.downcase!
                    end
                    if (test_path[0..(try.length-1)] == try)
                        action = path[(try.length)..-1]
                    end
                when Regexp
                    action_index = options[:action_match]
                    match = try.match(path)
                    if (match)
                        action = action_index ? match[action_index] : match.post_match
                        params = match[1..(match.length-1)]
                    end
                when Proc
                    res = try.call(path, self)
                    if (res)
                        if (res.is_a?(Array))
                            action = res[0]
                            params = res[1]
                        else
                            action = res
                        end
                    end
                end
                if (action)
                    if (dest.class == Symbol) # route to self
                        new_params = []
                        new_params << action if action && !action.empty?
                        new_params += (params || [])
                        params = new_params
                        action = dest.to_s
                        dest = self
                    end
                    params ||= []
                    # no leading slash 
                    action.slice!(0) if action.length > 0 && action[0].chr == '/'
                    return Route.new(:path => path, :dest => dest, :action => action, 
                                     :params => params, :options => options)
                end
            end
            return nil
        end
        
        def add_chain_item(method, proc, params)
            @dispatch_chains ||= {}
            @dispatch_chains[method] ||= []
            @dispatch_chain_index ||= {}
            @dispatch_chains[method] << [proc, params]
        end
        
        def run_chain(method, action='', *params)
            chain = dispatch_chain(method)
            return unless chain.length > 0
            @dispatch_chain_index ||= {}
            @dispatch_chain_index[method] = @dispatch_chain_index[method] ? @dispatch_chain_index[method]+1 : 0
            instance_eval(&chain[@dispatch_chain_index[method]][0]) if chain[@dispatch_chain_index[method]]
        end
        
        def dispatch_chain(method)
            our_chain =  @dispatch_chains && @dispatch_chains[method] ? @dispatch_chains[method] : []
            our_chain + self.class.dispatch_chain(method)
        end
        
        module ClassMethods
           
            def add_route(routes, path, dest=nil, options=nil)
                if ( path.is_a? Hash )
                    path.each {|p,d| add_route(p, d)}
                else
                    routes << [path, dest, options || {}]
                end
            end
            
            def route(path, dest=nil, options=nil)
                add_route(routes, path, dest, options)
            end
                        
            def routes
                @routes ||= []
            end
            
            def add_chain_item(method, proc, params)
                @dispatch_chains ||= {}
                @dispatch_chains[method] ||= []
                @dispatch_chains[method] << [proc, params]
            end
            
            def dispatch_chain(method)
                return [] unless @dispatch_chains && @dispatch_chains[method]
                @dispatch_chains[method]
            end
                
            
        end
        
        class Route
            attr_accessor :path, :dest, :action, :params, :options
            
            def initialize(args)
                @path = args[:path]
                @dest = args[:dest]
                @action = args[:action]
                @params = args[:params] || []
                @options = args[:options] || {}
            end
            
        end
        
        
    end
    
    
end