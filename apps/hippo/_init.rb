module Hippo
    @description = ""
    @version = 0.1
    @path = File.dirname(__FILE__)
    include Spider::App
end

require 'apps/hippo/models/mixins/hippo_struct'
require 'apps/hippo/models/security_user'
require 'apps/hippo/models/security_group'