require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class LayoutMeta < Block
        
        def compile(options={})
            init = ""
            c = ""
            type = @el.get_attribute('type')
            c += "output_meta"
            c+= "(:#{type})" if type
            c += "\n"
            return CompiledBlock.new(init, c)
        end

    end
    
    
end; end