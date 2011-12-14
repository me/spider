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

            html = ""
            @el.each_child do |ch|
                html += ch.to_html
            end
            runtime_content, overrides = klass.parse_content_xml(html)

            template = nil
            overrides += @template.overrides_for(id)
            
            asset_profiles = @el.get_attribute('sp:asset-profiles')
            if asset_profiles
                asset_profiles = asset_profiles.split(/,\s*/).map{ |pr| pr.to_sym } 
                @el.remove_attribute('sp:asset-profiles')
            end
            
            template = klass.load_template(template_attr || klass.default_template)
            template.asset_profiles = asset_profiles if asset_profiles
            # @template is the containing template, template is the widget's template
            if overrides.length > 0
                template.add_overrides overrides
                @template.add_subtemplate(id, template, klass)
            else
                @template.add_widget_template(template, klass)
            end

            init = ""
            t_param = 'nil'
            t_options = {}
            
            t_options[:asset_profiles] = asset_profiles if asset_profiles
            
            if (template)
                # FIXME: the subtemplate shouldn't be loaded at this point
                init = "t = load_subtemplate('#{id}', #{t_options.inspect})\n"
                t_param = 't'
            end
            html.gsub!("'", "\\\\'")
            
            init_params = self.class.attributes_to_init_params(@el.attributes.to_hash)
            runtime_content.gsub!("'", "\\\\'") if runtime_content
            
            init += "add_widget('#{id}', #{klass}.new(@request, @response), {#{init_params.join(', ')}}, '#{runtime_content}', #{t_param})\n"
            c = "yield :\"#{id}\"\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end