module Spider
    
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
        def route(path, dest=nil)
            p "ADDING ROUTE #{path}"
            @routes ||= []
            self.class.add_route(routes, path, dest)
        end
        
        
        
        def dispatch(path, env)
            klass, action = do_route(path)
            return handle(action) unless klass
            klass.new({
                :env => @env || nil,
                :scene => @scene || nil,
                :parent => self
            }).dispatch(action, env)
            $stderr << "Dispatcher Dispatched\n"
        end
        
        def do_route(path)
            Spider.logger.debug("Routing #{path}")
            r = routes + self.class.routes
            r.each do |route|
                try, dest = route
                action = nil
                case try
                when String
                    action = '' if (path == try)
                when Regexp
                    action = $1 if (path =~ try)
                end
                if (action)
                    return [dest, action]
                end
            end
            return nil
        end
        
        module ClassMethods
           
            def add_route(routes, path, dest=nil)
                if ( path.is_a? Hash )
                    path.each {|p,d| add_route(p, d)}
                else
                    routes << [path, dest]
                end
            end
            
            def route(path, dest=nil)
                add_route(routes, path, dest)
            end
            
            def routes
                @routes ||= []
            end
            
        end
        
        
    end
    
    
end