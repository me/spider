require 'spiderfw/controller/http_controller'

module Spider; module HTTP
    
    class Server
        
        @supports = {
            :chunked_request => false
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
            Spider.startup # TODO: if we decide to manage clusters, this will have to be moved outside
            trap('TERM') { shutdown }
            trap('INT') { shutdown }
            start_server(opts)
        end
        
        def shutdown
            Spider.logger.info("Webserver shutdown");
            shutdown_server
            Spider.shutdown # TODO: if we decide to manage clusters, this will have to be moved outside
        end
        
        def request_received
        end
        
    end
    
end; end