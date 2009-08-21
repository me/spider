require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Pass < Block
        
        def compile(options={})
            c, init = compile_content(c, init, options)
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end