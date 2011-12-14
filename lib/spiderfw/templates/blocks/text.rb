require 'spiderfw/templates/template_blocks'
require 'strscan'

module Spider; module TemplateBlocks
    ExpressionOutputRegexp = /\{?\{\s([^\s].*?)\s\}\}?/
    GettextRegexp = /([snp][snp]?)?_\(([^\)]+)?\)(\s%\s([^\s,]+(?:,\s*\S+\s*)?))?/
    ERBRegexp = /(<%(.+)?%>)/
    
    class Text < Block

        
        def compile(options={})
            text = @el.content
            c = ""
            Spider::Template.scan_text(text) do |type, val, full|
                case type
                when :plain
                    c += "$out << '#{escape_text(val)}'\n"
                when :escaped_expr
                    c += "$out << '{ #{escape_text(val)} }'\n"
                when :expr
                    c += "$out << #{vars_to_scene(val)}\n"
                when :gettext
                    c += "$out << #{val[:func]}_('#{escape_text(val[:val])}')"
                    if val[:vars]
                        c += " % [#{vars_to_scene(val[:vars])}]" 
                    end
                    c += "\n"
                when :erb
                    c += val
                end
            end
            return CompiledBlock.new(nil, c)
            
        end
        
        
        
    end
    
    
end; end