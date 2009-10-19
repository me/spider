require 'lib/spiderfw/i18n/provider'
require 'lib/spiderfw/i18n/rails'
begin
    require 'lib/spiderfw/i18n/cldr'
rescue LoadError
end

module Spider

    module I18n
        DefaultLocale = 'en'
        
        class << self
            
            def init
                @locales = {}
            end
            
            def providers
                [:CLDR, :Rails]
            end
            
            def provider(locale)
                @locales[locale] = load_locale(locale) unless @locales[locale]
                unless @locales[locale]
                    default = Spider.conf.get('i18n.default_locale')
                    load_locale(default) unless @locales[default]
                    return @locales[default]
                end
                return @locales[locale]
            end
                    
        
            def load_locale(locale)
                self.providers.each do |p|
                    res = try_provider(p, locale)
                    return res if res
                end
                return nil
            end
            
            def try_provider(const, locale)
                begin
                    res = const_get(const).new(locale)
                rescue => exc
                    return nil
                end
            end
            
            def localize(*args)
                localize_date_time(*args)
            end

            def localize_date_time(locale, object, format = :default, options={})
                raise ArgumentError, "Object must be a Date, DateTime or Time object. #{object.inspect} given." unless object.respond_to?(:strftime)
                p = provider(locale)
                unless p
                    Spider::Logger.error("No provider found for locale #{locale}")
                    return object.to_s
                end
                return p.localize_date_time(locale, object, format, options)
            end
            
            def parse_dt(locale, string, format = :default, options={})
                p = provider(locale)
                unless p
                    Spider::Logger.error("No provider found for locale #{locale}")
                    return Date.parse(string)
                end
                return p.parse_dt(locale, string, format, options)
            end
            
            def parse_date(locale, string, format = :default, options = {})
                parse_dt(locale, string, format, options.merge({:return => :date}))
            end

            def parse_datetime(locale, string, format = :default, options = {})
                parse_dt(locale, string, format, options.merge({:return => :datetime}))
            end
            
            # from Rails
            def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false)
                from_time = from_time.to_time if from_time.respond_to?(:to_time)
                from_time = from_time.to_local_time if from_time.respond_to?(:to_local_time)
                to_time = to_time.to_time if to_time.respond_to?(:to_time)
                to_time = to_time.to_local_time if to_time.respond_to?(:to_local_time)
                distance_in_minutes = (((to_time - from_time).abs)/60).round
                distance_in_seconds = ((to_time - from_time).abs).round

                case distance_in_minutes
                when 0..1
                    return (distance_in_minutes == 0) ? _('less than a minute') : _('1 minute') unless include_seconds
                    case distance_in_seconds
                    when 0..4   then _('less than %s seconds') % '5'
                    when 5..9   then _('less than %s seconds') % '10'
                    when 10..19 then _('less than %s seconds') % '20'
                    when 20..39 then _('half a minute')
                    when 40..59 then _('less than a minute')
                    else             _('1 minute')
                    end

                when 2..44           then _("%s minutes") % distance_in_minutes
                when 45..89          then _('about 1 hour')
                when 90..1439        then _("about %d hours") % (distance_in_minutes.to_f / 60.0).round
                when 1440..2879      then _('1 day')
                when 2880..43199     then _("%d days") % (distance_in_minutes / 1440).round
                when 43200..86399    then _('about 1 month')
                when 86400..525599   then _("%d months") % (distance_in_minutes / 43200).round
                when 525600..1051199 then _('about 1 year')
                else                      _("over %d years") % (distance_in_minutes / 525600).round
                end
            end
            
        end

    end
    I18n.init


end
