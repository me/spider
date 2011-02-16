require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Run < Block
        
        def escape_runtime_content(html)
            html.strip.gsub("'", "\\\\'")
        end
        
        def compile(options={})
            c = ""
            init = ""
            runtime_contents = @el.children ? @el.children_of_type('tpl:runtime-content') : []
            run_attributes = @el.attributes.to_hash
            if @el.has_attribute?('obj')
                scene_obj = var_to_scene(run_attributes.delete('obj'))
                widget_id = run_attributes.delete('widget')
                if widget_id
                    runtime_content_obj = "@widgets[#{widget_id}]" 
                else
                    runtime_content_obj = scene_obj
                end
                # runtime_contents.each do |rc|
                #     content = escape_runtime_content(rc.innerHTML)
                #     condition = ""
                #     if (rc.has_attribute?('for'))
                #         condition = " if #{runtime_content_obj}.local_id.to_s == '#{rc.get_attribute('for')}'"
                #     end
                #     parse_runtime = "#{runtime_content_obj}.parse_runtime_content_xml('<sp:widget-content>#{content}</sp:widget-content>')#{condition}\n"
                #     if widget_id
                #         init += parse_runtime
                #     else
                #         c += parse_runtime
                #     end
                #     @el.children.delete(rc)
                # end
                # unless @el.innerHTML.strip.empty?
                #     content = escape_runtime_content(@el.innerHTML)
                #     parse_runtime = "#{runtime_content_obj}.parse_runtime_content_xml('<sp:widget-content>#{content}</sp:widget-content>')\n"
                #     if widget_id
                #         init += parse_runtime
                #     else
                #         c += parse_runtime
                #     end
                # end
                if widget_id && @el.children
                    attributes = @el.children_of_type('sp:attribute')
                    init += "@owner.widget_attributes[#{widget_id}] ||= {}\n" if attributes.length > 0
                    attributes.each do |at|
                        attr_name = at.get_attribute('name').gsub("'", "\\\\'")
                        attr_value = at.get_attribute('value').gsub("'", "\\\\'")

                        init += "@owner.widget_attributes[#{widget_id}][:\"#{attr_name}\"] = '#{attr_value}'\n"
                    end
                end
                @el.innerHTML = ''
                c += "#{scene_obj}.render if (#{scene_obj})\n"
            end
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end