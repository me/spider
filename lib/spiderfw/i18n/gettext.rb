require 'fast_gettext'
require 'locale'
include FastGettext::Translation
FastGettext.add_text_domain('spider', :path => File.join($SPIDER_PATH, 'data', 'locale'))
FastGettext.text_domain = 'spider'
FastGettext.default_text_domain = 'spider'
l = Locale.current[0].to_s
l = $1 if l =~ /(\w\w)_+/
FastGettext.locale = l

module Spider
    
    module GetText
        
        # Executes a block of code in the given text_domain
        def self.in_domain(domain, &block)
            prev_text_domain = FastGettext.text_domain
            FastGettext.text_domain = domain if FastGettext.translation_repositories.key?(domain)
            v = yield
            FastGettext.text_domain = prev_text_domain
            v
        end

        # Sets the current text_domain; return the previous domain
        def self.set_domain(domain)
            prev_text_domain = FastGettext.text_domain
            FastGettext.text_domain = domain if FastGettext.translation_repositories.key?(domain)
            prev_text_domain
        end

        # Sets the current text_domain; assumes the domain was already set before, so skips any
        # check for domain validity
        def self.restore_domain(domain)
            FastGettext.text_domain = domain
        end
        
    end
    
end