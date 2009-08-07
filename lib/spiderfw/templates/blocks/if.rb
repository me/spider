require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class If < Block
        
        def compile(options={})
            init = ""
            init_cond = vars_to_scene(@el.attributes['sp:if'], 'scene')
            run_cond = vars_to_scene(@el.attributes['sp:if'])
            c = "if (#{run_cond})\n"
                
            @el.remove_attribute('sp:if')
            content = Spider::TemplateBlocks.parse_element(@el, @allowed_blocks, @template).compile(options)
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += "end\n"
            unless (content.init_code.strip.empty?)
                init = "if (#{init_cond})\n"
                content.init_code.each_line do |line|
                    init += "  #{line}"
                end
                init += "end\n"
            end
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end