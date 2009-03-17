require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Each < Block
        
        def initialize(el, template=nil, allowed_blocks=nil)
            @repeated = []
            super
        end
        
        def compile
            init = ""
            rep_type = nil
            rep = nil
            ['sp:each', 'sp:each_index'].each do |name|
                if (@el.attributes[name])
                    rep_type = name[3..-1]
                    rep = @el.attributes[name]
                    @el.remove_attribute(name)
                    break
                end
            end
            return nil unless rep_type
            if (rep =~ /\s*(.+)\s*\|\s*(.+)\s*\|/)
                repeated = $1.strip
                arguments = $2.strip
            end
            c = "#{var_to_scene(repeated)}.#{rep_type} do |#{arguments}|\n"
            content = Spider::TemplateBlocks.parse_element(@el, @allowed_blocks, @template).compile
            content.run_code.each_line do |line|
                c += '  '+line
            end
            c += '   $out << "\n"'
            c += "\n"
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