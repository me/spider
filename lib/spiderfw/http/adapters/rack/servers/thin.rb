require 'thin'
module Spider; module HTTP

    class Thin < Server
        
        def options(opts)
            opts = super(opts)
            defaults = {
                :host => 'localhost',
                :app => 'spider'
            }
            return defaults.merge(opts)
        end
        
        # start a Thin server on given host and port.

        # ==== Parameters
        # opts<Hash>:: Options for Thin (see below).
        #
        # ==== Options (opts)
        # :host<String>:: The hostname that Thin should serve.
        # :port<Fixnum>:: The port Thin should bind to.
        # :app<String>>:: The application name.
        def run_server(opts={})
            opts = options(opts)
            server = ::Thin::Server.start(opts[:host], opts[:port].to_i, opts[:app])
#            ::Thin::Logging.silent = true
            server.start!
        end
    end
    
end