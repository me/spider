require 'gettext/tools'
require 'spiderfw/templates/blocks/text'
require 'json'

module Spider; module I18n

    module JavascriptParser
        module_function
        
        GettextRegexp = /\W_\(['"]([^\)'"]+)['"](,\s*[^\)]+\s*)*\)/
        
        

        def target?(file)
            File.extname(file) == '.js'
        end

        def parse(file, ary)
            f = File.new(file)
            cnt = 0
            my_ary = []
            f.each_line do |line|
                cnt += 1
                scanner = ::StringScanner.new(line)
                while scanner.scan_until(GettextRegexp)
                    str = scanner.matched
                    str =~ GettextRegexp
                    found = false
                    (ary+my_ary).each do |msg|
                        if (msg[0] == $1)
                            msg << "#{file}:#{cnt}"
                            found = true
                            break
                        end
                    end
                    my_ary << [$1, "#{file}:#{cnt}"] unless found
                end
            end
            f.close
            unless my_ary.empty?
                dir = File.dirname(file)
                name = File.basename(file, '.js')
                i18n_file = File.join(dir, "#{name}.i18n.json")
                File.open(i18n_file, 'w') do |f|
                    f << my_ary.collect{ |a| a[0] }.to_json
                end
            end
            return ary + my_ary 
        end

    end
    
    ::GetText::RGetText.add_parser(JavascriptParser)

end; end