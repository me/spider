module Spider

    module WebDAV

        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        include Spider::App

    end


end

require 'apps/webdav/controllers/webdav_controller'