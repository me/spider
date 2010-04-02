module Spider; module I18n
    
    class Provider
        
        def localize(locale, object, format = :default, options={})
            raise "Unimplemented"
        end
        
        def default_calendar
            :gregorian
        end
        
        def day_names(format = :wide, calendar = self.default_calendar)
            raise "Unimplemented"
        end
        
        def month_names(format = :wide, calendar = self.default_calendar)
            raise "Unimplemented"
        end
        
        def week_start(calendar = self.default_calendar)
            raise "Unimplemented"
        end
        
        def weekend_start(calendar = self.default_calendar)
            raise "Unimplemented"
        end
        
        def weekend_end(calendar = self.default_calendar)
            raise "Unimplemented"
        end
        
    end
    
    
end; end