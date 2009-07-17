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
                p = p[0] if p.is_a?(Array)
                unless p
                    Spider::Logger.error("No provider found for locale #{locale}")
                    return object.to_s
                end
                return p.localize_date_time(locale, object, format, options)
            end
            
        end

    end
    I18n.init


end