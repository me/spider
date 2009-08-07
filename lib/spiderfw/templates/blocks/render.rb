require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Render < Block
        
        def compile(options={})
            c = ""
            init = nil
            if (@el.attributes['obj'] =~ /@(.+)/)
                c += "self[:#{$1}].render\n"
            end
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end