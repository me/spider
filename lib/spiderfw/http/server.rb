require 'spiderfw/controller/http_controller'

module Spider; module HTTP
    
    class Server
        
        @supports = {
            :chunked_request => false,
            :ssl => false
        }

        def self.supports?(capability)
            @supports[capability]
        end

        
        def options(opts={})
            defaults = {
                :host => '0.0.0.0',
                :port => 8080
            }
            return defaults.merge(opts)
        end
        
        def start(opts={})
            @options = opts
            Spider.logger.info{ "Routes: \n"+Spider::HomeController.print_app_routes }
            start_server(opts)
        end
        
        def shutdown
            Spider.logger.info("Webserver shutdown");
            shutdown_server            
        end
        
        def request_received
        end
        
    end
    
end; end