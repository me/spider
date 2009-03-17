require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class TagIf < Block
        
        def compile
            init = ""
            cond = vars_to_scene(@el.attributes['sp:tag-if'])
            @el.remove_attribute('sp:tag-if')
            html = HTML.new(@el, @template)
            c = "if (#{cond})\n"
            c += "  print  '#{html.get_start}'\n"
            c += "end\n"
            c, init = html.compile_content(c, init)
            tag_end = html.get_end
            if (tag_end)
                c += "if (#{cond})\n"
                c += "  print  '#{tag_end}'\n"
                c += "end\n"
            end
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end