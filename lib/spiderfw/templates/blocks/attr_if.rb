require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    # *sp:attr-if*
    # Adds an attribute if a condition holds
    # Example:
    #   <div sp:attr-if="@my_condition,class,coolDiv"></div>
    
    class AttrIf < Block
        
        def compile(options={})
            init = ""
            attr_if = @el.get_attribute('sp:attr-if')
            @el.remove_attribute('sp:attr-if')
            @el.set_attribute("tmp-attr-if", attr_if)
            compiled = Spider::TemplateBlocks.parse_element(@el, @allowed_blocks, @template).compile(options)
            c, init = compiled.run_code, compiled.init_code
            cond, name, val = attr_if.split(',')
            cond = vars_to_scene(cond)
            full_attr = val ? "#{name}=\"#{val}\"" : "#{name}"
            replace = "'+"+"( (#{cond}) ? '#{full_attr}' : '' )"+"+'"
#            debug("ATTR IF REPLACe")
            c.sub!('tmp-attr-if="'+attr_if+'"', replace)
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end