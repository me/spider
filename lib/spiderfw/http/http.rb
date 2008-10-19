module Spider
    module HTTP
        autoload :Server,   'spiderfw/http/server'
        #autoload :Thin,     'spiderfw/http/servers/thin'
        autoload :WEBrick,  'spiderfw/http/adapters/webrick'
        autoload :Mongrel,  'spiderfw/http/adapters/mongrel'
        autoload :Rack,     'spiderfw/http/adapters/rack/rack'
        
    end
    
end