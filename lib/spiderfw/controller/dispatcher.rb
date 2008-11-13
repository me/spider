module Spider
    
    # The includer of this module has to define a method dispatched_object, which must
    # return a child object given the class, the next action, and the route parameters
    module Dispatcher
        
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
            return obj.send(method, route.action, *(new_arguments))
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
            return [obj, next_route]
        end
        
        def dispatch_next(path)
            @dispatch_next ||= {}
            @dispatch_next[path] ||= do_route(path)
        end
        
        def get_route(path)
            Spider.logger.debug("Routing '#{path}'")
            r = routes + self.class.routes 
            r.each do |route|
                try, dest, options = route
                action = nil
                case try
                when String
                    test_path = path
                    if (options[:ignore_case])
                        test_path = path.downcase
                        try.downcase!
                    end
                    if (test_path[0..(try.length-1)] == try)
                        action = test_path[(try.length)..(test_path.length-1)]
                        params = [path[(try.length)..(path.length-1)]]
                    end
                when Regexp
                    action_index = options[:action_match]
                    match = try.match(path)
                    if (match)
                        action = action_index ? match[action_index] : match.post_match
                        params = match[1..(match.length-1)]
                    end
                end
                if (action)
                    if (dest.class == Symbol) # route to self
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