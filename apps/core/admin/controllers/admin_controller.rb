module Spider; module Admin
    
    class AdminController < Spider::PageController
        layout 'admin'

        include Spider::Auth::AuthHelper
        require_user Spider::Auth::SuperUser # add Auth::Administrator


        def before(action='', *params)
            super
            return unless is_target? # FIXME! the whole is_target thing is not working as it should
            @scene.username = @request.user.username
            @scene.apps = []
            @scene.admin_breadcrumb = [{:url => self.class.url, :label => _('Home')}]
            Admin.apps.each do |short_name, app|
                url = self.class.http_url(short_name)
                @scene.apps << {
                    :icon => app[:module].pub_url+'/'+app[:options][:icon],
                    :url => self.class.http_url(short_name),
                    :name => app[:module].full_name,
                    :description => app[:module].description,
                    :module => app[:module],
                    :priority => app[:options][:priority] || 1
                }
            end
            # FIXME
            @scene.apps.sort!{ |a,b| a[:priority] <=> b[:priority] }
        end

        __.html :template => 'index'
        def index
        end
        
    end
    
    
end; end