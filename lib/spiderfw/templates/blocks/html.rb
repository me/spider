require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class HTML < Block
        
        def compile
            c = ""
            init = ""
            start = get_start
            c += "$out << '#{start}'\n"
            c, init = compile_content(c, init)
            end_tag = get_end
            c += "$out << '#{end_tag}'\n" if end_tag
            return CompiledBlock.new(init, c)
        end
        
        def get_start
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
            start += " /" unless @el.etag
            start += ">"
            return start
        end
        
        def get_end
            str = escape_text(@el.etag.inspect) if @el.etag
            str = str[1..-2] if str && str[0] == '"' # Work around Hpricot 0.8 differences
            return str
        end
        
    end
    
    
end; end