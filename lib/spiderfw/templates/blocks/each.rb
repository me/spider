require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Each < Block
        
        def initialize(el, allowed_blocks=nil)
            @repeated = []
            super
        end
        
        def compile
            init = ""
            rep = @el.attributes['sp:each']
            @el.remove_attribute('sp:each')
            if (rep =~ /\s*(.+)\s*\|\s*(.+)\s*\|/)
                repeated = $1.strip
                arguments = $2.strip
            end
            c = "#{var_to_scene(repeated)}.each do |#{arguments}|\n"
            content = Spider::TemplateBlocks.parse_element(@el).compile
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += "end\n"
            init += content.init_code
            return CompiledBlock.new(init, c)
        end
        
        def get_following(el)
            return false if (el.class == ::Hpricot::Text)
            if (el.name == 'sp:repeated')
                @repeated << el
            end
        end
        
    end
    
    
end; end