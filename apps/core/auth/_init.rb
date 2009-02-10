module Spider
    module Auth
        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        include Spider::App
        
        def self.current_user
            Thread.current[:current_user]
        end
        
        def self.current_user=(uid)
            Thread.current[:current_user] = User.new(uid)
        end
        
        class Unauthorized < SecurityError
        end
    end
end

require 'apps/core/auth/models/mixins/access_control'
require 'apps/core/auth/models/user'
require 'apps/core/auth/models/group'
require 'apps/core/auth/models/login_user'
require 'apps/core/auth/controllers/login_controller'
require 'apps/core/auth/controllers/helpers/auth_helper'
