require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Yield < Block
        
        def compile(options={})
            init = nil
            to = @el.get_attribute('to') || 'yield_to'
            #c = "self[:yield_to][:controller].send(self[:yield_to][:action], *self[:yield_to][:arguments])\n"
            c = "yield :#{to}\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end