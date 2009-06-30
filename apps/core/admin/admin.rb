module Spider
    
    module Admin
    
        def self.apps
            @apps.values
        end
        
        def self.add(app)
            @apps[app.name] = app
        end
        
        
    end
    
    
end