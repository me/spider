require 'date'
require 'time'

# Monkey-patched conversions to Date and DateTime
class Time
    def lformat(format = :default, locale=nil)
        locale ||= Spider.locale
        Spider::I18n.localize(locale, self, format)
    end
    
    def to_date
        ::Date.new(year, month, day)
    end
    def to_datetime
        ::DateTime.civil(year, month, day, hour, min, sec, Rational(utc_offset, 86400))
    end
end