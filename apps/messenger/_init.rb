Spider.load_app('core/admin')

module Spider

    module Messenger

        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        @controller = :MessengerController
        include Spider::App

    end
    
    Spider::Admin.add(Messenger)
    
end

require 'apps/messenger/messenger'
require 'apps/messenger/controllers/messenger_controller'