require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Comment < Block
        
        def compile(options={})
            init = nil
            c = ""
            str = nil
            mode = nil
            if (@el.content[0].chr == '-')
                mode = :internal
            elsif (@el.content[0].chr == '+')
                mode = :parse
            else
                mode = :verbatim
            end
            if (mode == :parse)
                str = ""
                rest = scan_vars(@el.to_s) do |text, code|
                    str += escape_text(text)+"'+("+vars_to_scene(code)+").to_s+'"
                end
                str += escape_text(rest)
            elsif (mode == :verbatim)
                str = escape_text(@el.to_s)
            else
                str = nil
            end
            c += "$out << '#{str}'\n" if str
            #c += "$out << '#{@el.to_s}'\n"
            return CompiledBlock.new(init, c)
        end

    end
    
    
end; end