require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Each < Block
        
        def initialize(el, allowed_blocks=nil)
            @repeated = []
            super
        end
        
        def compile
            Spider.logger.debug("COMPILING; REPEATED:")
            Spider.logger.debug(@repeated)
            init = ""
            rep = @el.attributes['sp:each']
            @el.remove_attribute('sp:each')
            Spider.logger.debug("REP: #{@el}")
            if (rep =~ /\s*(.+)\s*\|\s*(.+)\s*\|/)
                repeated = $1.strip
                arguments = $2.strip
            end
            Spider.logger.debug("REPEATED:")
            Spider.logger.debug(@el.attributes)
            c = "#{var_to_scene(repeated)}.each do |#{arguments}|\n"
            c += "Spider.logger.debug('INPUT:')\nSpider.logger.debug(input)\n"
            Spider.logger.debug("REPETITION:")
            Spider.logger.debug(c)
            content = Spider::TemplateBlocks.parse_element(@el).compile
            c += content.run_code
            init += content.init_code
            c += "end\n"
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