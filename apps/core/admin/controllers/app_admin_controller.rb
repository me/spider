module Spider; module Admin

    class AppAdminController < Spider::PageController
        include Spider::Auth::AuthHelper

        def before(action='', *params)
            @scene.admin_breadcrumb ||= []
            unless @_did_breadcrumb
                @scene.admin_breadcrumb << {:url => self.class.http_url, :label => self.class.app.full_name}
            end
            @_did_breadcrumb = true
            super
            unless check_action(action, :login)
                our_app = Spider::Admin.apps[self.class.app.short_name]
                raise "Admin #{self.class.app.short_name} not configured" unless our_app
                user_classes = our_app[:options][:users] || Spider::Admin.base_allowed_users
                unless user_classes.include?(@request.user.class)
                    raise Spider::Auth::Unauthorized.new(_("User not authorized to access this application"))
                end
                if our_app[:options][:check]
                    unless our_app[:options][:check].call(@request.user)
                        raise Spider::Auth::Unauthorized.new(_("User not authorized to access this application"))
                    end
                end
            end
        end

    end

end; end
