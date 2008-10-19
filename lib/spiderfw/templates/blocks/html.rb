require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class HTML < Block
        
        def compile
            c = ""
            init = ""
            Spider.logger.debug(@el.attributes)
            start = "<"+@el.name
            @el.attributes.each do |key, val|
                start += " #{key}=\""
                if (val =~ /(.*)\{ (.+) \}(.*)/)
                    Spider.logger.debug("VARIABLE ATTR: #{val}")
                    start += $1+"'+"+var_to_scene($2)+".to_s+'"+$3
                else
                    start += val
                end
                start += '"'
            end
            start += ">"
            c += "print '#{start}'\n"
            blocks = parse_content(@el)
            c, init = compile_content(c, init)
            c += "print '#{escape_text(@el.etag.inspect)}'\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end