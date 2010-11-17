require 'spiderfw/templates/template_blocks'
require 'strscan'

module Spider; module TemplateBlocks
    ExpressionOutputRegexp = /\{?\{\s([^\s].*?)\s\}\}?/
    GettextRegexp = /_\(([^\)]+)?\)(\s%\s([^\s,]+(?:,\s*\S+\s*)?))?/
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
                    c += "$out << _('#{escape_text(val[0])}')"
                    if val[1]
                        c += " % [#{vars_to_scene(val[1])}]" 
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