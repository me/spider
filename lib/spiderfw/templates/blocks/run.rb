require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Run < Block
        
        def compile(options={})
            c = ""
            init = nil
            runtime_contents = @el.children ? @el.children_of_type('tpl:runtime-content') : []
            if (@el.has_attribute?('obj'))
                scene_obj = var_to_scene(@el.get_attribute('obj'))
                runtime_contents.each do |rc|
                    content = rc.innerHTML.strip
                    content.gsub!("'", "\\\\'")
                    condition = ""
                    if (rc.has_attribute?('for'))
                        condition = " if #{scene_obj}.local_id.to_s == '#{rc.get_attribute('for')}'"
                    end
                    c += "#{scene_obj}.parse_runtime_content_xml('#{content}')#{condition}\n"
                end
                c += "#{scene_obj}.render if (#{scene_obj})\n"
            end
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end