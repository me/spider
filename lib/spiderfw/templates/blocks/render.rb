require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks

    class Render < Block

        def compile(options={})
            c = ""
            init = ""
            if (@el.attributes['obj'])
                c_scene_obj = var_to_scene(@el.attributes['obj'])
                i_scene_obj = var_to_scene(@el.attributes['obj'], 'scene')
                init += "#{i_scene_obj}.request = @request\n"
                init += "#{i_scene_obj}.response = @response\n"
                c += "#{c_scene_obj}.render(self)\n"
            end
            return CompiledBlock.new(init, c)
        end

    end


end; end