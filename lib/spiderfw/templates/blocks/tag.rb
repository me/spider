module Spider; module TemplateBlocks
    
    class Tag < Block

        
        def compile(options={})
            block = Spider::TemplateBlocks.parse_element(process, @allowed_blocks, @template)
            return block.compile(options)
        end
        
        def process
            klass = Spider::Template.get_registered_class(@el.name)
            tag = klass.new(@el)
            return Hpricot(tag.render).root
        end
        
        
    end
    
    
end; end