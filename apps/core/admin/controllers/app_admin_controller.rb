module Spider; module Admin

    class AppAdminController < Spider::PageController

        def before(action='', *params)
            unless @_did_breadcrumb
                @scene.admin_breadcrumb << {:url => self.class.url, :label => self.class.app.full_name}
            end
            @_did_breadcrumb = true
            super
        end

    end

end; end