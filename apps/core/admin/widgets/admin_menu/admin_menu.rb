module Spider; module Admin
    
    class AdminMenu < Spider::Components::Menu
        tag 'menu'
        
        def init
            @use_template = 'menu'
            super
            Spider::Admin.apps.each do |app|
                add(_('Applications'), app.label, '/'+app.route_url)
            end
        end
        
    end
    
    
end; end