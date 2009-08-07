module Spider; module TemplateBlocks
    
    class Tag < Block

        
        def compile(options={})
            klass = Spider::Template.get_registered_class(@el.name)
            tag = klass.new(@el)
            block = Spider::TemplateBlocks.parse_element(Hpricot(tag.render).root, @allowed_blocks, @template)
            return block.compile(options)
        end
        
        
    end
    
    
end; end