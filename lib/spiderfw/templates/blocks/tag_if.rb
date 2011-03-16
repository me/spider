require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class TagIf < Block
        
        def compile(options={})
            init = ""
            cond = vars_to_scene(@el.get_attribute('sp:tag-if'))
            @el.remove_attribute('sp:tag-if')
            html = HTML.new(@el, @template)
            c = "if (#{cond})\n"
            c += html.get_start(options)
            c += "end\n"
            c, init = html.compile_content(c, init, options)
            tag_end = html.get_end(options)
            if (tag_end)
                c += "if (#{cond})\n"
                c += "  $out <<  '#{tag_end}'\n"
                c += "end\n"
            end
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end