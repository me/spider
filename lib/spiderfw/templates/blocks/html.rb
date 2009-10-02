require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class HTML < Block
        
        def compile(options={})
            c = ""
            init = ""
            start = get_start(options)
            c += "$out << '#{start}'\n"
            options.delete(:root)
            c, init = compile_content(c, init, options)
            end_tag = get_end
            c += "$out << '#{end_tag}'\n" if end_tag
            return CompiledBlock.new(init, c)
        end
        
        def get_start(options)
            if options[:mode] == :widget
                cl = @el.attributes['class'] || ''
                if @el.attributes['id']
                    cl += ' ' unless cl.empty?
                    cl += "id-#{@el.attributes['id']}"
                    @el.raw_attributes.delete('id')
                end
                if (options[:root])
                    cl += " widget"
                    if options[:owner_class]
                        cl += " wdgt-#{options[:owner_class].name.gsub('::', '-')}"
                    end
                    @el.raw_attributes['id'] =  "{ @widget[:full_id] }"
                end
                cl += ' ' unless cl.empty?
                cl += '{ @widget[:css_classes] }'
                @el.raw_attributes['class'] = cl
            end
            start = "<"+@el.name
            @el.attributes.each do |key, val|
                start += " #{key}=\""
                rest = scan_vars(val) do |text, code|
                    start += text+"'+("+vars_to_scene(code)+").to_s+'"
                end
                start += rest
#                start += replace_vars(val)
                # if (val =~ /(.*)\{ (.+) \}(.*)/)
                #     start += $1+"'+"+var_to_scene($2)+".to_s+'"+$3
                # else
                #     start += val
                # end
                start += '"'
            end
            #start += " /" unless @el.etag
            start += ">"
            return start
        end
        
        def get_end
            str = escape_text(@el.etag.inspect) if @el.etag
            str = str[1..-2] if str && str[0].chr == '"' # FIXME:  This is a workaround Hpricot 0.6 and 0.8 differences
            return str
        end
        
    end
    
    
end; end