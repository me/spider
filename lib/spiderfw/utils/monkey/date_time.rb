# A couple of monkey-patched utility methods.
#--
# (from Rails)
class Date

    # Converts to a Time object in the GMT timezone.
    def to_gm_time
        to_time(new_offset, :gm)
    end

    # Converts to a Time object in the local timezone.
    def to_local_time
        to_time(new_offset(DateTime.now.offset-offset), :local)
    end
    
    def lformat(format = :default, locale=nil, options={})
        locale ||= Spider.locale
        Spider::I18n.localize(locale, self, format, options)
    end

    private
    def to_time(dest, method)
        #Convert a fraction of a day to a number of microseconds
        usec = (dest.sec_fraction * 60 * 60 * 24 * (10**6)).to_i
        Time.send(method, dest.year, dest.month, dest.day, dest.hour, dest.min,
        dest.sec, usec)
    end
end