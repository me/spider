# A couple of monkey-patched utility methods.
#--
# (partially from Rails)
class Date

    # Converts to a Time object in the GMT timezone.
    def to_gm_time
        to_time(new_offset, :gm)
    end

    # Converts to a Time object in the local timezone.
    def to_local_time
        conv_to_time(new_offset(DateTime.now.offset), :local)
    end
    
    def to_date
        ::Date.new(year, month, day)
    end
    
    def lformat(format = :default, locale=nil, options={})
        locale ||= Spider.locale
        Spider::I18n.localize(locale, self, format, options)
    end
    
    def self.lparse(string, format = :default, locale=nil, options={})
        locale ||= Spider.locale
        options[:return] = self <= DateTime ? :datetime : :date 
        Spider::I18n.parse_dt(locale, string, format, options)
    end
    
    # Custom clone for home_run gem
    def clone
        if self.respond_to?(:hour)
            self.class.civil(self.year, self.month, self.day, self.hour, self.min, self.sec, self.offset)
        else
            self.class.civil(self.year, self.month, self.day)
        end
    end

    private
    def conv_to_time(dest, method)
        #Convert a fraction of a day to a number of microseconds
        usec = (dest.send(:sec_fraction) * 60 * 60 * 24 * (10**6)).to_i
        if dest.respond_to?(:hour)
            Time.send(method, dest.year, dest.month, dest.day, dest.hour, dest.min, dest.sec, usec)
        else
            Time.send(method, dest.year, dest.month, dest.day)
        end
    end
end

class Time
    
    def self.lparse(string, format = :default, locale=nil, options={})
        locale ||= Spider.locale
        options[:return] = :time
        Spider::I18n.parse_dt(locale, string, format, options)
    end
    
    # if RUBY_VERSION_PARTS[1] == '8'
    #     
    #     def self.strptime(string, format=nil)
    #         Date.strptime(string, format).to_local_time
    #     end
    #     
    # end
    
end