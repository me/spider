require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Yield < Block
        
        def compile
            init = nil
            #c = "self[:yield_to][:controller].send(self[:yield_to][:action], *self[:yield_to][:arguments])\n"
            c = "self[:yield_to_template].render(self)\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end