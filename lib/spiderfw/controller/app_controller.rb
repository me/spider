require 'spiderfw/controller/mixins/static_content'

module Spider

    class AppController < Controller
        # FIXME: should extend PageController, but there are some circular dependencies to sort out.
        include Visual
        include StaticContent
        include WidgetHelper


    end

end