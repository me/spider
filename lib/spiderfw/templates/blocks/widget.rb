require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Widget < Block
        
        def compile
            klass = Spider::Template.get_registered_class(@el.name)
            init_params = []
            run_params = []
            id = @el.attributes['id']
            raise TemplateCompileError, "Widget #{@el.name} does not have an id" unless id
            template_attr = @el.attributes['template']
            @el.remove_attribute('template')
            @el.attributes.each do |key, val|
                if (val[0].chr == '@')
                    pval = "self[:#{val[1..-1]}]"
                    sval = "scene[:#{val[1..-1]}]"
                else
                    pval = '"'+val+'"'
                    sval = pval
                end
                init_params << ":#{key} => #{sval}"
                run_params << ":#{key} => #{pval}"                
            end
            # Hpricot fails me when doing a direct search for >tpl:override
            # overrides = @el.search('>tpl:override') + @el.search('>tpl:override-content')
            overrides = []
            @template.override_tags.each do |tag|
                overrides += @el.children_of_type('tpl:'+tag)
            end
            template = nil
            if (overrides.length > 0)
                #template_name = klass.find_template(template_attr)
                template = klass.load_template(template_attr || klass.default_template)
                template.overrides = overrides
                @template.add_subtemplate(id, template)
            end
            # FIXME: can't find a better way
            overrides.each{ |o| o.set_attribute('class', 'to_delete') }
            @el.search('.to_delete').remove
            html = ""
            @el.each_child do |ch|
                html += ch.to_html
            end
            html.gsub!("'", "\\'")
            html = "<sp:widget-content>#{html}</sp:widget-content>" unless html.empty?
            init = ""
            t_param = 'nil'
            if (template)
                # FIXME: the subtemplate shouldn't be loaded at this point
                init = "t = load_subtemplate('#{id}')\n"
                t_param = 't'
            end
            init += "add_widget('#{id}', #{klass}.new(@request, @response), {#{init_params.join(', ')}}, '#{html}', #{t_param})\n"
            c = "yield :#{id}\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end