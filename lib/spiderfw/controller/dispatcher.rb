module Spider
    
    # The includer of this module has to define a method dispatched_object, which must
    # return a child object given the class, the next action, and the route parameters
    module Dispatcher
        attr_accessor :dispatch_previous
        
        def self.included(klass)
           klass.extend(ClassMethods)
        end
        
        # Defined routes.
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
        
        # Given a method and an action, returns a triplet containing
        # - the object on which to call the method
        # - the new action
        # - the new arguments
        def dispatch(method, action='', *arguments)
            return nil unless can_dispatch?(method, action)
            route = @dispatch_next[action]
            obj = route.obj            
            new_arguments = arguments
            new_arguments += route.params unless route.options[:remove_params]
            return [obj, route.action, new_arguments]
#            return obj.send(method, route.action, *(new_arguments))
        end
        
        # Dispatches the given method and action:
        # will get an object and new action and arguments from #dispatch,
        # and then call the method on the object, with new action and new arguments as params.
        # 
        # If #dispatch_methods are defined, will call them *before* calling method.
        # After calling method, will call a method called "#{method}_{new_action.downcase}", if it exists
        # 
        # Example:
        #   do_dispatch(:before, 'section_b/news/list')
        # will get obj (in the example, the 'section_b' controller) and call
        #   # any method configured in dispatch_methods
        #   obj.before('news/list')
        #   obj.before_news
        def do_dispatch(method, action='', *arguments)
            obj, route_action, new_arguments = dispatch(method, action, *arguments)
            return nil unless obj
            return nil if obj == self && route_action == action # short circuit
            meth_action = route_action.length > 0 ? route_action : obj.class.default_action
            begin
                # Apply dispatch methods (see {Controller.before})
                if obj.class.dispatch_methods && obj.class.dispatch_methods[method]
                    obj.class.dispatch_methods[method].each do |dm|
                        conditions, d_method, params = dm
                        test = check_action(route_action, conditions)
                        test = !test if params[:unless]
                        obj.send(d_method, route_action, *new_arguments) if (test)
                    end
                end
                res = obj.send(method, route_action, *(new_arguments))
                # Call, for example, before_my_method
                unless meth_action.empty?
                    meth_action = meth_action[0..-2] if meth_action[-1].chr == '/'
                    meth_action = meth_action.split('/', 2)[0]
                    try_meth = "#{method}_#{meth_action.downcase}"
                    res = obj.send(try_meth, *new_arguments) if obj.respond_to?(try_meth)
                end
                return res
            rescue StandardError, SecurityError => exc
                if (obj.respond_to?(:try_rescue))
                    obj.send(:try_rescue, exc)
                else
                    raise
                end
            end
        end

        
        # Returns true if there is a route for action, and the routed object responds to method.
        def can_dispatch?(method, action)
            d_next = dispatch_next(action)
            return false unless d_next
            if (d_next.dest.is_a?(Class))
                return false unless d_next.dest.method_defined?(method)
            else
                return false unless d_next.dest.respond_to?(method)
            end
            return true
        end
        
        # Returns the (possibly cached) route for path.
        def dispatch_next(path)
            @dispatch_next ||= {}
            @dispatch_next[path] ||= dispatcher_get_route(path)
        end

        def dispatcher_get_route(path)
	    route = get_route(path)
            return route if !route || route.obj
            obj = dispatched_object(route)
            obj.dispatch_previous = self if obj.respond_to?(:dispatch_previous=) && obj != self
            route.obj = obj
            if route.options[:do]
                do_args = [route.matched] + (route.params || [])
                obj.instance_exec(*(do_args).slice(0, route.options[:do].arity), &route.options[:do])
            end
            route.obj = obj
            route
        end
        
        # Looks in defined routes, and returns the first matching Route for path.
        def get_route(path)
	    path ||= ''
            r = routes + self.class.routes
            if nil_route = self.class.nil_route
                r << [nil, nil_route[0], nil_route[1]]
            end
            r.each do |route|
		try, dest, options = route
                action = nil
                nil_route = false
                next if options[:http_method] && @request.http_method != options[:http_method]
                case try
                when true, nil
                    action = path
                    matched = nil
                    nil_route = true
                when String
                    test_path = path
                    if (options[:ignore_case])
                        test_path = path.downcase
                        try.downcase!
                    end
		    if (test_path == try || (test_path[0..(try.length-1)] == try && (try[-1].chr == '/' || test_path[try.length].chr == '/'))) 	
			action = path[(try.length)..-1]
                        matched = try
                    end
                when Regexp
                    action_index = options[:action_match]
                    match = try.match(path)
                    if (match)
                        action = action_index ? match[action_index] : match.post_match
                        action = action[0..-2] if action.length > 0 && action[-1].chr == '/'
                        params = match[1..(match.length-1)]
                        matched = match[0]
                    end
                when Proc
                    res = try.call(path, self)
                    if res
                        if res.is_a?(Array)
                            action = res[0]
                            params = res[1]
                            matched = res[1]
                        else
                            action = res
                        end
                    end
                when Symbol
                    if Spider::HTTP::METHODS.include?(try)
                        if @request.http_method == try
                            action = path
                            matched = nil
                        end
                    end
                end
                if action
                    action = action[1..-1] if action[0] && action[0].chr == '/'
                    if (options[:prepend])
                        action = options[:prepend] + action
                    end
                    if (dest.class == Symbol) # route to self
                        new_params = []
                        new_params << action if action && !action.empty?
                        new_params += (params || [])
                        params = new_params
                        action = dest.to_s
                        dest = self
                    end
                    params ||= []
                    action.sub!(/^\/+/, '') # no leading slash

                    return Route.new(:path => path, :dest => dest, :action => action, :matched => matched,
                                     :nil_route => nil_route, :params => params, :options => options)
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
            attr_accessor :default_route, :default_dispatcher, :nil_route
           
            def add_route(routes, path, dest=nil, options=nil)
                if path.is_a?(Hash)
                    path.each {|p,d| add_route(p, d)}
                elsif path.nil?
                    @nil_route = [dest, options || {}]
                else
                    routes << [path, dest, options || {}]
                    if path.is_a?(String) && dest.respond_to?(:default_dispatcher=)
                        dest.default_dispatcher = self
                        dest.default_route = path
                    end
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
            
            def dispatch_methods
                @dispatch_methods
            end
            
            def check_action(action, check)
                checks = check.is_a?(Array) ? check : [check]
                action = action.to_s
                action = default_action if action == ''
                action = action[0..-1] if action[-1].chr == '/'
                checks.each do |check|
                    if check.is_a?(String)
                        return true if (action == check || (action[-1].chr == '/' && action[0..-2] == check))
                    elsif check.is_a?(Regexp)
                        return true if action =~ check
                    elsif check.is_a?(Proc)
                        return true if check.call(action)
                    elsif (check.is_a?(Symbol))
                        first, rest = action.split('/', 2)
                        return true if first && first.to_sym == check
                    end
                end
                return false
            end
            
        end
        
        class Route
            attr_accessor :path, :dest, :action, :params, :options, :matched, :obj, :nil_route
            
            def initialize(args)
                @path = args[:path]
                @dest = args[:dest]
                @action = args[:action]
                @params = args[:params] || []
                @options = args[:options] || {}
                @matched = args[:matched]
                @nil_route = args[:nil_route]
                @obj = nil
            end
            
        end
        
        
    end
    
    
end
