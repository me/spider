module Spider
    module Auth
        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        include Spider::App
        
        def self.current_user
            Spider.current[:current_user]
        end
        
        def self.current_user=(uid)
            Spider.current[:current_user] = User.new(uid)
        end
        
        class Unauthorized < SecurityError
            attr_accessor :user
            
            def initialize(msg, user=nil)
                super msg
                @user = user if user
            end
            
        end
    end
end

require 'apps/core/auth/lib/authenticable'
require 'apps/core/auth/lib/login_authenticator'
require 'apps/core/auth/lib/digest_authenticator'
#require 'apps/core/auth/models/mixins/access_control'
require 'apps/core/auth/models/mixins/authentication_tracking'
require 'apps/core/auth/models/user'
require 'apps/core/auth/models/login_user'
require 'apps/core/auth/models/digest_user'
require 'apps/core/auth/models/super_user'
require 'apps/core/auth/controllers/login_controller'
require 'apps/core/auth/controllers/mixins/auth_helper'
require 'apps/core/auth/controllers/mixins/http_basic_auth'
require 'apps/core/auth/controllers/mixins/http_digest_auth'

Spider::Auth.route 'login', Spider::Auth::LoginController
