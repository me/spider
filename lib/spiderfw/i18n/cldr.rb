require 'yaml'
require 'cldr'
require 'locale'

module Spider; module I18n
    
    # Formats: short, medium, full, long
    class CLDR < Provider
                
        def initialize(locale)
            @locale = locale
            @cldr = ::CLDR::Object.new(:locale => locale.to_cldr)

        end

        def localize_date_time(object, format = 'medium', options={})
            options[:calendar] ||= 'gregorian'
            format = 'medium' if format == :default
                        
            time_format = nil
            date_format = nil
            format_string = nil
            calendar = options[:calendar].to_sym
            if (object.respond_to?(:sec) && !options[:no_time])
                time_format = @cldr.calendar.timeformats[calendar][format.to_s].dup
            end
            if (object.is_a?(Date))
                date_format = @cldr.calendar.dateformats[calendar][format.to_s].dup
            end
            if (date_format && time_format)
                # in CLDR 1.x, datetimeformats is an hash of strings indexed by strings;
                # in CLDR 2.x, it is a hash of hashes indexed by symbols
                fts = @cldr.calendar.datetimeformats[calendar] || @cldr.calendar.datetimeformats[calendar.to_s]
                dt_f = fts.is_a?(String) ? fts : fts[format.to_s] 
                format_string = dt_f.sub('{1}', date_format).sub('{0}', time_format)
            else
                format_string = date_format ? date_format : time_format
            end

            # FIXME: handle more efficiently
            d = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
            obj_d = d[object.wday]
            days = @cldr.calendar.days[options[:calendar].to_sym]
            months = @cldr.calendar.months[options[:calendar].to_sym]
            replacements = [
                [/y{1,4}/, '%Y'], # year  don't use two digits year, they cause confusion [/y{1,2}/, '%y']
                [/M{5}/, months[:narrow][object.month.to_s]], [/M{4}/, months[:wide][object.month.to_s]], #month
                [/M{3}/, months[:abbreviated][object.month.to_s]], [/M{1,2}/, '%m'], 
                [/L{5}/, months[:narrow][object.month.to_s]], [/L{4}/, months[:wide][object.month.to_s]], #month
                [/L{3}/, months[:abbreviated][object.month.to_s]], [/L{1,2}/, '%m'], 
                [/E{5}/, days[:narrow][obj_d]], [/E{4}/, days[:wide][obj_d]], [/E{1,3}/, days[:abbreviated][obj_d]], #day of the week
                [/e{1,5}/, '%w'], #day of the week (numeric)
                [/d{1,2}/, '%d'], # day of the month
                [/h{1,2}/, '%I'], [/H{1,2}/, '%H'], [/a/, '%p'], #hour
                [/m{1,2}/, '%M'], [/s{1,2}/, '%S'], # seconds
                [/z{1,4}/, '%Z'], [/Z{1,4}/, '%Z'], [/V{1,4}/, '%Z'] # time zone
            ]
            format_string = mgsub(format_string, replacements)

            if (time_format)
                am = @cldr.calendar.am[options[:calendar].to_s]
                pm = @cldr.calendar.pm[options[:calendar].to_s]
                format_string.gsub!(/%p/, object.hour < 12 ? 'am' : 'pm') if object.respond_to? :hour
            end
            object.strftime(format_string)
        end
        
        # FIXME: add extended format handling like in localize
        def parse_dt(string, format = 'medium', options = {})
            format = 'medium' if format == :default
            options[:calendar] ||= 'gregorian'
            
            time_format = @cldr.calendar.timeformats[options[:calendar].to_sym][format.to_s].dup
            date_format = @cldr.calendar.dateformats[options[:calendar].to_sym][format.to_s].dup
            if (options[:return] == :datetime)
                dt_f = @cldr.calendar.datetimeformats[options[:calendar].to_sym][format.to_s]
                format_string = dt_f.sub('{1}', date_format).sub('{0}', time_format)
                klass = DateTime
            elsif (options[:return] == :date)
                format_string = date_format
                klass = Date
            elsif (options[:return] == :time)
                format_string = time_format
                klass = Time
            end
            replacements = [
                [/y{1,4}/, '%Y'], # year      don't use two digits year [/y{1,2}/, '%y'],
                [/M{1,5}/, '%m'],
                [/L{1,5}/, '%m'],
                [/E{1,5}/, ''], #day of the week
                [/e{1,5}/, '%w'], #day of the week (numeric)
                [/d{1,2}/, '%d'], # day of the month
                [/h{1,2}/, '%I'], [/H{1,2}/, '%H'], [/a/, '%p'], #hour
                [/m{1,2}/, '%M'], [/s{1,2}/, '%S'], # seconds
                [/z{1,4}/, '%Z'], [/Z{1,4}/, '%Z'], [/V{1,4}/, '%Z'] # time zone
            ]
            format_string = mgsub(format_string, replacements)
            if options[:return] == :time
                DateTime.strptime("01-01-2000T#{string}#{Time.now.strftime('%Z')}", "%d-%m-%YT#{format_string}%Z").to_local_time
            else
                klass.strptime(string, format_string)
            end
        end
        
        
        def prepare_format_string(obj, string)
 
        end
        
        def mgsub(string, key_value_pairs)
            regexp_fragments = key_value_pairs.collect { |k,v| k }
            string.gsub( 
            Regexp.union(*regexp_fragments)) do |match|
                key_value_pairs.detect{|k,v| k =~ match}[1]
            end
        end
        
        def day_names(format = :wide, calendar = self.default_calendar)
            begin
                days = @cldr.calendar.days[calendar][format]
                return [days['sun'], days['mon'], days['tue'], days['wed'], days['thu'], days['fri'], days['sat']]
            rescue NoMethodError
                raise ArgumentError, "Calendar #{calendar} not found" unless @cldr.days[calendar]
                raise ArgumentError, "Format #{format} not found"
            end
            
        end
        
        def month_names(format = :wide, calendar = self.default_calendar)
            months = []
            begin
                @cldr.calendar.months[calendar][format].each do |k, v|
                    months[k.to_i] = v
                end
            rescue NoMethodError
                raise ArgumentError, "Calendar #{calendar} not found" unless @cldr.months[calendar]
                raise ArgumentError, "Format #{format} not found"
            end
            months
        end
        
        def week_start(calendar = self.default_calendar)
            wdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
            day = if @cldr.respond_to?(:supplemental)
                @cldr.supplemental.week_data["firstDay"]
            elsif @cldr.calendar.respond_to?(:week_firstdays) # CLDR 1
                @cldr.calendar.week_firstdays[calendar.to_s]
            end
            day ||= 'mon'
            wdays.index day
            
        end
        
        def weekend_start(calendar = self.default_calendar)
            wdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
            day = if @cldr.respond_to?(:supplemental)
                @cldr.supplemental.week_data["weekendStart"]
            elsif @cldr.calendar.respond_to?(:weekend_starts) # CLDR 1
                @cldr.calendar.weekend_starts[calendar.to_s]
            end
            day ||= 'sat'
            wdays.index day
        end
        
        def weekend_end(calendar = self.default_calendar)
            wdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
            day = if @cldr.respond_to?(:supplemental)
                @cldr.supplemental.week_data["weekendEnd"]
            elsif @cldr.calendar.respond_to?(:weekend_ends) # CLDR 1
                @cldr.calendar.weekend_ends[calendar.to_s]
            end
            day ||= 'sun'
            wdays.index day
        end
        
        def localize_number(object, precision=nil, options={})
            delimiter = @cldr.number.symbol_group
            separator = @cldr.number.symbol_decimal
            Spider::I18n.do_localize_number(object, delimiter, separator, precision, options)
        end
        
        def parse_number(string, options={})
            delimiter = @cldr.number.symbol_group
            separator = @cldr.number.symbol_decimal
            Spider::I18n.do_parse_number(string, delimiter, separator, options)
        end

        def list(enumerable)
            return enumerable.join(', ') unless @cldr.core.respond_to?(:list_patterns) # old cldr version
            patterns = @cldr.core.list_patterns
            str = ""

            def sub_pattern(pattern, items)
                str = pattern.clone
                items.each_index do |i|
                    str.sub!("{#{i}}", items[i])
                end
                str
            end
            if pattern = patterns[enumerable.length.to_s]
                return sub_pattern(pattern, enumerable)
            end
            length = enumerable.length
            str = enumerable.last.to_s
            (length-2).downto(0) do |i|
                pattern = nil
                if i == length -2
                    pattern = patterns['end']
                elsif i == 0
                    pattern = patterns['start']
                end
                pattern ||= patterns['middle']
                str = sub_pattern(pattern, [enumerable[i].to_s, str])
            end
            return str

        end
        
    end
    
end; end
