require 'gettext/tools'
require 'spiderfw/templates/blocks/text'

module Spider; module I18n

    module SHTMLParser
        module_function

        def target?(file)
            File.extname(file) == '.shtml'
        end

        def parse(file, ary)
            f = File.new(file)
            cnt = 0
            f.each_line do |line|
                cnt += 1
                scanner = ::StringScanner.new(line)
                while scanner.scan_until(Spider::TemplateBlocks::GettextRegexp)
                    str = scanner.matched
                    str =~ Spider::TemplateBlocks::GettextRegexp
                    found = false
                    ary.each do |msg|
                        if (msg[0] == $2)
                            msg << "#{file}:#{cnt}"
                            found = true
                            break
                        end
                    end
                    ary << [$2, "#{file}:#{cnt}"] unless found
                end
            end
            f.close
            return ary    
        end

    end
    
    ::GetText::RGetText.add_parser(SHTMLParser)

end; end