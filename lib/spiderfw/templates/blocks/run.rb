require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Run < Block
        
        def compile(options={})
            c = ""
            init = nil
            obj = 
            if (@el.attributes['obj'])
                scene_obj = var_to_scene(@el.attributes['obj'])
                c += "#{scene_obj}.render if (#{scene_obj})\n"
            end
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end