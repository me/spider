require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Run < Block
        
        def compile
            c = ""
            init = nil
            obj = 
            if (@el.attributes['obj'])
                c += "#{var_to_scene(@el.attributes['obj'])}.render\n"
            end
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end