require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Run < Block
        
        def compile(options={})
            c = ""
            init = nil
            runtime_contents = @el.children_of_type('tpl:runtime-content')
            if (@el.attributes['obj'])
                scene_obj = var_to_scene(@el.attributes['obj'])
                runtime_contents.each do |rc|
                    content = rc.innerHTML.strip
                    content.gsub!("'", "\\\\'")
                    condition = ""
                    if (rc.attributes['for'])
                        condition = " if #{scene_obj}.local_id.to_s == '#{rc.attributes['for']}'"
                    end
                    c += "#{scene_obj}.parse_runtime_content_xml('#{content}')#{condition}\n"
                end
                c += "#{scene_obj}.render if (#{scene_obj})\n"
            end
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end