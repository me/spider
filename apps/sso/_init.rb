module Spider

    module SSO

        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        include Spider::App

    end


end

require 'apps/sso/lib/saml2'
require 'apps/sso/controllers/mixins/saml2_mixin'