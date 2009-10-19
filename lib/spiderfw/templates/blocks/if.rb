require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class If < Block
        
        def compile(options={})
            init = ""
            init_cond = nil
            if_attr = @el.attributes['sp:if'] || @el.attributes['sp:run-if']
            init_cond = vars_to_scene(@el.attributes['sp:if'], 'scene') if @el.attributes['sp:if']
            run_cond = vars_to_scene(if_attr)
            c = "if (#{run_cond})\n"
            @el.remove_attribute('sp:if')
            @el.remove_attribute('sp:run-if')
            content = Spider::TemplateBlocks.parse_element(@el, @allowed_blocks, @template).compile(options)
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += "end\n"
            unless (!content.init_code || content.init_code.strip.empty?)
                init += "if (#{init_cond})\n" if init_cond
                content.init_code.each_line do |line|
                    init += "  #{line}"
                end
                init += "end\n" if init_cond
            end
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end