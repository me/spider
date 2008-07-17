require 'webrick'
require 'rack/handler/webrick'

module Spider; module HTTP; module Rack

    class WEBrick < ::Spider::HTTP::Server
        
        def options(opts)
            opts = super(opts)
            defaults = {
                :host => 'localhost',
                :app => 'spider'
            }
            return defaults.merge(opts)
        end
        

        def start_server(opts={})
            opts = options(opts)
            options = {
                :Port           => opts[:port],
                :BindAddress    => opts[:host]
            }
            @server = ::WEBrick::HTTPServer.new(options)
            @server.mount("/", ::Rack::Handler::WEBrick, ::Spider::HTTP::Rack::Application.new)
            @server.start
        end
        
        def shutdown_server
            @server.shutdown
        end
        
    end
    
end; end; end