require 'spiderfw/templates/template_blocks'
require 'strscan'

module Spider; module TemplateBlocks
    
    class Text < Block

        
        def compile
            text = @el.content
            scanner = ::StringScanner.new(text)
            pos = 0
            c = ""
            while scanner.scan_until(/(\{.+?\})|(_\(.+?\))|(<%.+?%>)/)
                #debugger
                text = scanner.pre_match[pos..-1]
                pos = scanner.pos
                #$out << escape_text(text) if (text && text.length > 0)
                c += "$out << '#{escape_text(text)}'\n" if (text && text.length > 0)
                case scanner.matched
                when /\{ (.+) \}/
                    c += "$out << #{vars_to_scene($1)}\n"
                when /_\((.+)\)/
                    c += "$out << _('#{escape_text($1)}')\n"
                when /<%(.+)%>/
                    c += $1
                end
            end
            text = scanner.rest
            c += "$out << '#{escape_text(text)}'\n" if (text && text.length > 0)
            return CompiledBlock.new(nil, c)
        end
        
        
    end
    
    
end; end