require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Debugger < Block
        
        def compile(options={})
            c = "debugger\n"
            init = nil
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end