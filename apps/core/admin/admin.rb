module Spider
    
    module Admin
    
        def self.apps
            @apps ||= Spider::OrderedHash
        end

        def self.register_app(mod, controller, options)
            @apps[mod.short_name] = {
                :module => mod,
                :controller => controller,
                :options => options || {}
            }

            Admin::AdminController.route mod.short_name, controller, :do => lambda{ |app_name|
                @scene.current_app = Spider::Admin.apps[app_name]
            }
        end

        def self.allowed_users
            users = []
            @apps.each do |name, app|
                users += app[:options][:users] if app[:options][:users]
            end
            users += self.base_allowed_users
            users.uniq
        end

        def self.base_allowed_users
            [Spider::Auth::SuperUser]
        end
        
        
    end
    
    
end