module Spider

    module Soap

        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        include Spider::App

    end


end

require 'apps/soap/lib/soap'
require 'apps/soap/controllers/soap_controller'