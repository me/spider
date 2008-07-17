module Spider; module HTTP
    
    class Server
        
        def options(opts={})
            defaults = {
                :port => 8080
            }
            return defaults.merge(opts)
        end
        
        def start(opts={})
            trap('TERM') { shutdown }
            trap('INT') { puts "\nExiting"; shutdown }
            start_server(opts)
        end
        
        def shutdown
            shutdown_server
        end
        
    end
    
end; end