module Spider
    module Master
        @short_name = 'master'
        include Spider::App
        @controller = :MasterController
        
        
        
    end
end

require 'apps/master/master'

require 'apps/master/models/admin'
require 'apps/master/models/customer'
require 'apps/master/models/installation'
require 'apps/master/models/command'
require 'apps/master/models/event'
require 'apps/master/models/remote_log'
require 'apps/master/models/server'
require 'apps/master/models/scout_plugin_info'
require 'apps/master/models/scout_plugin_instance'
require 'apps/master/models/scout_report'
require 'apps/master/models/scout_error'
require 'apps/master/models/scout_alert'
require 'apps/master/lib/scout_plugin'
require 'apps/master/controllers/master_controller'
require 'apps/app_server/app_server'
require 'apps/master/controllers/scout_controller'
require 'apps/master/lib/site_type'
require 'apps/master/plugins/site_types/spider/spider'


