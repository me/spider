require 'yaml'

module Spider; module I18n
    
    class Rails < Provider
        
        def initialize(locale)
            @locale = load_locale(locale)
        end


        def load_locale(locale)
            orig_locale = locale
            file, locale = find_locale(locale)
            l = load_locale_file(file) if file
            @locale_data = l[locale] if l
            raise ArgumentError unless @l
            @locale_data.extend(Spider::HashDottedAccess)
            return locale
        end

        def load_locale_file(filename)
            type = File.extname(filename).tr('.', '').downcase
            if (type == 'rb')
                return eval(IO.read(filename), binding, filename)
            elsif (type == 'yml')
                return YAML::load(IO.read(filename))
            end
        end


        def find_locale(locale)
            try = locale.to_s
            while (try)
                extensions = ['yml', 'rb']
                extensions.each do |ext|
                    full_path = Spider.conf.get('i18n.rails_path')+'/'+try+'.'+ext
                    return [full_path, try] if (File.exist?(full_path))
                end
                if (try =~ (/^([^\.-_@]+)[\.-_@]/))
                    try = $1
                else
                    try = false
                end
            end
        end

        def localize_date_time(locale, object, format = :default, options={})
            l = @locale_data
            type = object.respond_to?(:sec) ? 'time' : 'date'
            formats = l["#{type}.formats"]
            format = formats[format.to_s] if formats && formats[format.to_s]
            raise "Format #{format} not found" unless format

            format = format.to_s.dup

            format.gsub!(/%a/, l['date.abbr_day_names'][object.wday])
            format.gsub!(/%A/, l["date.day_names"][object.wday])
            format.gsub!(/%b/, l["date.abbr_month_names"][object.mon])
            format.gsub!(/%B/, l["date.month_names"][object.mon])
            format.gsub!(/%p/, l["time.#{object.hour < 12 ? :am : :pm}"]) if object.respond_to? :hour
            object.strftime(format)
        end
        
        # FIXME: add extended format handling like in localize
        def parse_date_time(locale, string, format = :default, options={})
            l = @locale_data
            type = object.respond_to?(:sec) ? 'time' : 'date'
            formats = l["#{type}.formats"]
            format = formats[format.to_s] if formats && formats[format.to_s]
            raise "Format #{format} not found" unless format

            format = format.to_s.dup
            if (options[:return] == :datetime)
                klass = DateTime
            elsif (options[:return] == :date)
                klass = Date
            end
            object.strptime(format)
        end
        
        def localize_number(number, precision=nil, options={})
            l = @locale_data
            defaults           = l["number.format"]
            precision_defaults = l["number.precision.format"]
            defaults           = defaults.merge(precision_defaults)
            separator = (options[:separator] || defaults[:separator])
            delimiter = (options[:delimiter] || defaults[:delimiter])
            
            Spider::I18n.do_localize_number(number, delimiter, separator, precision, options)
            
        end
        
        def parse_number(string, options={})
            l = @locale_data
            defaults           = l["number.format"]
            precision_defaults = l["number.precision.format"]
            defaults           = defaults.merge(precision_defaults)
            separator = (options[:separator] || defaults[:separator])
            delimiter = (options[:delimiter] || defaults[:delimiter])
            
            Spider::I18n.do_parse_number(string, delimiter, separator, options)
        end
        

        
        def time_ago_in_words(from_time, include_seconds = false)
          distance_of_time_in_words(from_time, Time.now, include_seconds)
        end
        
    end
    
end; end