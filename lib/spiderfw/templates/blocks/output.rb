require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Output < Block
        
        def compile(options={})
            init = nil
            c = ""
            str = escape_text(@el.get_attribute('text'))
            c += "$out << '#{str}'\n"
            return CompiledBlock.new(init, c)
        end

    end
    
    
end; end