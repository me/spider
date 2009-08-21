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
            try = locale
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
        

        
        def time_ago_in_words(from_time, include_seconds = false)
          distance_of_time_in_words(from_time, Time.now, include_seconds)
        end
        
    end
    
end; end