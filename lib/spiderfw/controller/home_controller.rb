module Spider

    class HomeController < Controller
        include StaticContent, HTTPMixin
        route 'spider/public', Spider.controller, :prepend => 'public/'
        #        route 'spider', Spider.controller

        def self.route_app(app)
            #app_path = app.name.gsub('::', '/')
            app_path = app.route_url
            route(app_path, app.controller, :ignore_case => true)
            self.app_routes << [app_path, app.controller]
        end

        def self.pub_path
            Spider.paths[:root]+'/public'
        end

        def self.pub_url
            HTTPMixin.reverse_proxy_mapping('/public')
        end
        
        def self.app_pub_path(app=nil)
            path = self.pub_path+'/apps'
            path += '/'+app.short_name if app
            path
        end
        
        def self.app_routes
            @app_routes ||= []
        end
        
        def self.print_app_routes(routes=app_routes)
            max_length = routes.inject(0){ |m, r| m > r[0].length ? m : r[0].length }
            routes.map{ |r| "#{r[0].ljust(max_length+3)} -> #{r[1]}"}.sort.join("\n")
        end

    end


end
