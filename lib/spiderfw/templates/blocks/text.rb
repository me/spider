require 'spiderfw/templates/template_blocks'
require 'strscan'

module Spider; module TemplateBlocks
    ExpressionOutputRegexp = /\{\s([^\s].*?)\s\}/
    GettextRegexp = /_\((.+)?\)(\s%\s([^\s,]+)(,\s*\S+\s*\])?)?/
    ERBRegexp = /(<%(.+)?%>)/
    
    class Text < Block

        
        def compile(options={})
            text = @el.content
            scanner = ::StringScanner.new(text)
            pos = 0
            c = ""
            while scanner.scan_until(Regexp.union(ExpressionOutputRegexp, GettextRegexp, ERBRegexp))
                text = scanner.pre_match[pos..-1]
                pos = scanner.pos
                c += "$out << '#{escape_text(text)}'\n" if (text && text.length > 0)
                case scanner.matched
                when ExpressionOutputRegexp
                    c += "$out << #{vars_to_scene($1)}\n"
                when GettextRegexp
                    c += "$out << _('#{escape_text($1)}')"
                    if $2
                        c += " #{vars_to_scene($2)}" 
                    end
                    c += "\n"
                when ERBRegexp
                    c += $1
                end
            end
            text = scanner.rest
            c += "$out << '#{escape_text(text)}'\n" if (text && text.length > 0)
            return CompiledBlock.new(nil, c)
        end
        
        
        
    end
    
    
end; end