module Spider; module HTTP
    
    class Server

        
        def options(opts={})
            defaults = {
                :host => '0.0.0.0',
                :port => 8080
            }
            return defaults.merge(opts)
        end
        
        def start(opts={})
            trap('TERM') { shutdown }
            trap('INT') { shutdown }
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