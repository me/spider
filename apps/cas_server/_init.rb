module Spider

    module CASServer

        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        @gem_dependencies = [
            'isaac' => '>0.2.5'
        ]
        include Spider::App


    end


end

['mixins/consumable', 'ticket', 'login_ticket', 
'ticket_granting_ticket', 'proxy_granting_ticket', 'proxy_ticket'].each do |mod|
    require 'apps/cas_server/models/'+mod
end
require 'apps/cas_server/controllers/mixins/cas_login_mixin'