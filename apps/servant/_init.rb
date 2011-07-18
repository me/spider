module Spider
    module Servant
        @short_name = 'servant'
        include Spider::App
        @controller = :ServantController
    end
end

require 'apps/servant/controllers/servant_controller'