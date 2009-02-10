require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class If < Block
        
        def compile
            init = ""
            cond = @el.attributes['sp:if']
            scanner = ::StringScanner.new(cond)
            pos = 0
            c = "if ("
            while scanner.scan_until(/@(\w[\w\d_]+)/)
                text = scanner.pre_match[pos..-1]
                pos = scanner.pos
                c += text
                c += "scene[:#{scanner.matched[1..-1]}]"
            end
            c+= scanner.rest
            c+= ")\n"
                
            @el.remove_attribute('sp:if')
            content = Spider::TemplateBlocks.parse_element(@el).compile
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += "end\n"
            init += content.init_code
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end