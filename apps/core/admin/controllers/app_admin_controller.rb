module Spider; module Admin

    class AppAdminController < Spider::PageController

        def before(action='', *params)
            @scene.admin_breadcrumb ||= []
            unless @_did_breadcrumb
                @scene.admin_breadcrumb << {:url => self.class.http_url, :label => self.class.app.full_name}
            end
            @_did_breadcrumb = true
            super
            our_app = Spider::Admin.apps[self.class.app.short_name]
            if our_app[:options][:users]
                unless our_app[:options][:users].include?(@request.user.class)
                    raise Unauthorized.new(_("User not authorized to access this application"))
                end
            end
            if our_app[:options][:check]
                unless our_app[:options][:check].call(@request.user)
                    raise Unauthorized.new(_("User not authorized to access this application"))
                end
            end
        end

    end

end; end
