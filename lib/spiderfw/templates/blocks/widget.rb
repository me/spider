require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Widget < Block
        
        def compile
            init = nil
            klass = const_get_full(Spider::Template.registered[@el.name])
            params = []
            @el.attributes.each do |key, val|
                if (val[0].chr == '@')
                    pval = "self[:#{val[1..-1]}]"
                else
                    pval = '"'+val+'"'
                end
                params << ":#{key} => #{val}"
            end
            c = "w = #{klass}.new(nil, nil, {#{params.join(', ')}})\n" # FIXME: this must be in init,
                                                                       # and must pass env and scene
            c += "w.run\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end