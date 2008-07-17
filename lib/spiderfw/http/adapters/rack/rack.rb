module Spider; module HTTP
    module Rack
        autoload :Application,  'spiderfw/http/adapters/rack/application'
        autoload :WEBrick,      'spiderfw/http/adapters/rack/servers/webrick'
    end
end; end