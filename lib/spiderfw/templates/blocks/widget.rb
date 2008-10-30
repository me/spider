require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Widget < Block
        
        def compile
            klass = const_get_full(Spider::Template.registered[@el.name])
            init_params = []
            run_params = []
            id = @el.attributes['id']
            raise TemplateCompileError, "Widget #{@el.name} does not have an id" unless id
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
            html = ""
            @el.each_child do |ch|
                html += ch.to_html
            end
            html.gsub!("'", "\\'")
            init = "add_widget('#{id}', #{klass}.new(), nil, nil, {#{init_params.join(', ')}}, '#{html}')\n"
            c = "self[:widgets][:#{id}].run\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end