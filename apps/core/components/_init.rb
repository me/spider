module Spider
    module Components
        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        include Spider::App

    end
end

Spider::Template.register_namespace('core', Spider::Components)

require 'apps/core/components/widgets/table/table'
require 'apps/core/components/widgets/crud/crud'
require 'apps/core/components/widgets/menu/menu'
require 'apps/core/components/widgets/admin/admin'