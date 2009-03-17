require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class If < Block
        
        def compile
            init = ""
            cond = vars_to_scene(@el.attributes['sp:if'])
            c = "if (#{cond})\n"
                
            @el.remove_attribute('sp:if')
            content = Spider::TemplateBlocks.parse_element(@el, @allowed_blocks, @template).compile
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += "end\n"
            unless (content.init_code.strip.empty?)
                init = "if (#{cond})\n"
                content.init_code.each_line do |line|
                    init += "  #{line}"
                end
                init += "end\n"
            end
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end