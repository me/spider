require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    # *sp:attr-if*
    # Adds an attribute if a condition holds
    # Example:
    #   <div sp:attr-if="@my_condition,class,coolDiv"></div>
    # The attribute's value can be a scene variable, but not an expression: so
    #  <div sp:attr-if"@my_condition,attr_name,@attr_value" /> is valid, but
    #  <div sp:attr-if"@my_condition,attr_name,@attr_value_start+@attr_value_end" /> is not
    
    class AttrIf < Block
        
        def compile(options={})
            init = ""
            attr_if = @el.get_attribute('sp:attr-if')
            @el.remove_attribute('sp:attr-if')
            @el.set_attribute("tmp-attr-if", '---')
            compiled = Spider::TemplateBlocks.parse_element(@el, @allowed_blocks, @template).compile(options)
            c, init = compiled.run_code, compiled.init_code
            cond, name, val = attr_if.split(',')
            if val && val.strip[0].chr == '@'
                val = "'+#{var_to_scene(val)}+'"
            end
            cond = vars_to_scene(cond)
            full_attr = val ? "#{name}=\"#{val}\"" : "#{name}"
            replace = "'+"+"( (#{cond}) ? '#{full_attr}' : '' )"+"+'"
#            debug("ATTR IF REPLACe")
            c.sub!('tmp-attr-if="---"', replace)
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end