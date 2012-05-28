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
require 'apps/core/forms/widgets/inputs/hidden/hidden'
require 'apps/core/forms/widgets/inputs/text_area/text_area'
require 'apps/core/forms/widgets/inputs/date_time/date_time'
require 'apps/core/forms/widgets/inputs/select/select'
require 'apps/core/forms/widgets/inputs/search_select/search_select'
require 'apps/core/forms/widgets/inputs/password/password'
require 'apps/core/forms/widgets/inputs/checkbox/checkbox'
require 'apps/core/forms/widgets/inputs/checkbox_list/checkbox_list'
require 'apps/core/forms/widgets/inputs/file_input/file_input'
require 'apps/core/forms/widgets/inputs/time_span/time_span'
require 'apps/core/forms/widgets/inputs/html_area/html_area'