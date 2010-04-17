class Numeric
    
    def lformat(precision = nil, locale=nil, options={})
        locale ||= Spider.locale
        Spider::I18n.localize_number(locale, self, precision, options)
    end
    
    def self.lparse(string)
        locale ||= Spider.locale
        options = {}
        options[:return] = self
        Spider::I18n.parse_number(locale, string)
    end
    
end