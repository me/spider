require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Widget < Block
        
        def self.attributes_to_init_params(attributes)
            init_params = []
            attributes.each do |key, val|
                if (!val.empty? && val[0].chr == '@')
                    sval = var_to_scene(val, 'scene')
                elsif (!val.empty? && val[0].chr == '$')
                    sval = val[1..-1]
                else
                    sval = '"'+val+'"'
                end
                init_key = key
                init_key = "\"#{init_key}\"" unless key =~ /^[\w\d]+$/
                init_params << ":#{init_key} => #{sval}"
            end
            init_params
        end
        
        def compile(options={})
            klass = Spider::Template.get_registered_class(@el.name)
            init_params = []
            id = @el.get_attribute('id')
            raise TemplateCompileError, "Widget #{@el.name} does not have an id" unless id
            template_attr = @el.get_attribute('template')
            @el.remove_attribute('template')
            if klass.respond_to?(:compile_block)
                init, c = klass.compile_block(@el, id, @el.attributes.to_hash, options)
                return CompiledBlock.new(init, c)
            end
            init_params = self.class.attributes_to_init_params(@el.attributes.to_hash)

            html = ""
            @el.each_child do |ch|
                html += ch.to_html
            end
            html = "<sp:widget-content>#{html}</sp:widget-content>" unless html.empty?
            runtime_content, overrides = klass.parse_content_xml(html)

            template = nil
            overrides += @template.overrides_for(id)
            if (overrides.length > 0)
                #template_name = klass.find_template(template_attr)
                template = klass.load_template(template_attr || klass.default_template)
                template.add_overrides overrides
                @template.add_subtemplate(id, template, klass)
            end


            init = ""
            t_param = 'nil'
            if (template)
                # FIXME: the subtemplate shouldn't be loaded at this point
                init = "t = load_subtemplate('#{id}')\n"
                t_param = 't'
            end
            html.gsub!("'", "\\\\'")
            init += "add_widget('#{id}', #{klass}.new(@request, @response), {#{init_params.join(', ')}}, '#{html}', #{t_param})\n"
            c = "yield :#{id}\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end