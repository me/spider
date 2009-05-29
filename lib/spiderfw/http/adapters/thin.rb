require 'thin'
require 'spiderfw/http/adapters/rack'

module Spider; module HTTP
    
    class Thin < Server
        
        @supports = {
            :chunked_request => false
        }

        def options(opts)
            opts = super(opts)
            defaults = {
                :host   => 'localhost',
                :app    => 'spider'
            }
            return defaults.merge(opts)
        end


        def start_server(opts={})
            opts = options(opts)
            options = {
                :Port           => opts[:port],
                :BindAddress    => opts[:host]
            }
            @server = ::Thin::Server.start(opts[:host], opts[:port].to_i, Spider::HTTP::RackApplication.new)
        end

        def shutdown_server
            @server.stop
        end
        
    end
    
    
end; end