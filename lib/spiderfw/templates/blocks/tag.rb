module Spider; module TemplateBlocks
    
    class Tag < Block

        
        def compile
            klass = Spider::Template.get_registered_class(@el.name)
            tag = klass.new(@el)
            block = Spider::TemplateBlocks.parse_element(Hpricot(tag.render).root, @allowed_blocks, @template)
            return block.compile
        end
        
        
    end
    
    
end; end