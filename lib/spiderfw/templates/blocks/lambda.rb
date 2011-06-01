require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Lambda < Block
        
        def compile(options={})
            init = ""
            lambda_name = @el.attributes['sp:lambda']
            @el.remove_attribute('sp:lambda')
            c = "#{lambda_name} = lambda do\n"            
            content = Spider::TemplateBlocks.parse_element(@el, @allowed_blocks, @template).compile(options)
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += "end\n"
            c += "#{lambda_name}.call"
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end