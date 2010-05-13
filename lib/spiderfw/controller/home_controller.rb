module Spider

    class HomeController < Controller
        include StaticContent
        route 'spider/public', Spider.controller, :prepend => 'public/'
        #        route 'spider', Spider.controller

        def self.route_app(app)
            #app_path = app.name.gsub('::', '/')
            app_path = app.route_url
            Spider::Logger.debug("ROUTING #{app_path} TO #{app.controller}")
            route(app_path, app.controller, :ignore_case => true)
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

    end


end
