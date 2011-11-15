module Spider
    
    module Admin
    
        def self.apps
            @apps ||= Spider::OrderedHash
        end

        def self.register_app(mod, controller, options)
            @apps[mod.short_name] = {
                :module => mod,
                :controller => controller,
                :options => options
            }

            Admin::AdminController.route mod.short_name, controller, :do => lambda{ |app_name|
                @scene.current_app = Spider::Admin.apps[app_name]
            }
        end
        
        
    end
    
    
end