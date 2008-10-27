require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Widget < Block
        
        def compile
            klass = const_get_full(Spider::Template.registered[@el.name])
            init_params = []
            run_params = []
            id = @el.attributes['id']
            @el.attributes.each do |key, val|
                if (val[0].chr == '@')
                    pval = "self[:#{val[1..-1]}]"
                    sval = "scene[:#{val[1..-1]}]"
                else
                    pval = '"'+val+'"'
                    sval = pval
                end
                init_params << ":#{key} => #{sval}"
                run_params << ":#{key} => #{pval}"
                
                Spider::Logger.debug("PARAMS:")
                Spider::Logger.debug(init_params)
            end
            init = "add_widget('#{id}', #{klass}.new(nil, nil, {#{init_params.join(', ')}}))\n" # FIXME: this must be in init,
                                                                       # and must pass env and scene
            c = "self[:widgets][:#{id}].run\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end