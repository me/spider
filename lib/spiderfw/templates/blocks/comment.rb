require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Comment < Block
        
        def compile
            init = nil
            c = ""
            str = ""
            rest = scan_vars(@el.to_s) do |text, code|
                str += escape_text(text)+"'+("+vars_to_scene(code)+").to_s+'"
            end
            str += escape_text(rest)
            c += "$out << '#{str}'\n"
            return CompiledBlock.new(init, c)
        end

    end
    
    
end; end