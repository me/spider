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
                user_classes = our_app[:options][:users] || []
                user_classes += Spider::Admin.base_allowed_users
                if (user_classes & (@request.users.map{ |u| u.class})).empty?
                    raise Spider::Auth::Unauthorized.new(_("User not authorized to access this application"))
                end
                if our_app[:options][:check]
                    unless @request.users.any?{ |u| our_app[:options][:check].call(u) }
                        raise Spider::Auth::Unauthorized.new(_("User not authorized to access this application"))
                    end
                end
            end
        end

    end

end; end
