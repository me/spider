require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class If < Block
        
        def compile
            init = ""
            cond = vars_to_scene(@el.attributes['sp:if'])
            scanner = ::StringScanner.new(cond)
            pos = 0
            c = "if (#{cond})\n"
                
            @el.remove_attribute('sp:if')
            content = Spider::TemplateBlocks.parse_element(@el).compile
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += "end\n"
            init += content.init_code
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end