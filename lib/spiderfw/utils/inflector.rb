module Spider

    module Inflector

        #--
        # From ActiveSupport
        def self.camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
            if first_letter_in_uppercase
                lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
            else
                lower_case_and_underscored_word.first + camelize(lower_case_and_underscored_word)[1..-1]
            end
        end

        #--
        # From ActiveSupport
        def self.underscore(camel_cased_word)
            camel_cased_word.to_s.gsub(/::/, '/').
            gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
            gsub(/([a-z\d])([A-Z])/,'\1_\2').
            tr("-", "_").
            downcase
        end
        
        def self.underscore_to_upcasefirst(str)
            upcasefirst(str.gsub(/_+/, ' '))
        end
        
        def self.upcasefirst(str)
            # FIXME: move to language specific!
            no_upcase = ['di', 'da', 'a']
            res = str.split(' ').map do | p | 
                l = p.downcase
                l.gsub(/^[a-z]/){ |a| a.upcase } unless no_upcase.include?(l)
            end
            res.join(' ')
        end
        

    end

end