module Spider; module Master
    
    class SiteType
        
        def self.inherited(klass)
            Spider::Master.add_site_type(klass)
        end
        
        def self.details
            self.const_get(:DETAILS)
        end
        
        def self.id
            details[:id]
        end
        
        def self.name
            details[:name]
        end
        
        
    end
    
end; end