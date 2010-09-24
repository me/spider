module Spider
    module AppServer
        include Spider::App
        @controller = :AppServerController
    end
end

require 'apps/app_server/controllers/app_server_controller'
