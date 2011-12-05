require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class TextDomain < Block
        
        def compile(options={})
            init = ""
            td = @el.get_attribute('tpl:text-domain')
            c = "Spider::GetText.in_domain('#{td}') do\n"
            @el.remove_attribute('tpl:text-domain')
            content = Spider::TemplateBlocks.parse_element(@el, @allowed_blocks, @template).compile(options)
            init += content.init_code
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += "end\n"
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end