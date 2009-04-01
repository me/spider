module Spider
    module Forms
        @description = ""
        @version = 0.1
        @path = File.dirname(__FILE__)
        include Spider::App

    end
end

Spider::Template.register_namespace('forms', Spider::Forms)

require 'apps/core/forms/widgets/form/form'
require 'apps/core/forms/widgets/inputs/input/input'
require 'apps/core/forms/widgets/inputs/text/text'
require 'apps/core/forms/widgets/inputs/select/select'
require 'apps/core/forms/widgets/inputs/search_select/search_select'
require 'apps/core/forms/widgets/inputs/password/password'