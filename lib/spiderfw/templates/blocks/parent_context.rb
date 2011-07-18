require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    # *sp:parent-context*
    # Executes the content using the parent's scene
    
    class ParentContext < Block
        
        def compile(options={})
            init = ""
            c = ""
#            c += "debugger\n"
            parent_c, parent_init = compile_content(c, init, options)
            parent_c.gsub!("'", "\\\\'")
            #parent_init.gsub!("'", "\\\\'")
            init = parent_init
            init.gsub!('scene[', 'scene[:_parent][')
            c += "self[:_parent].instance_eval('def __run_block\n;#{parent_c}\nend\n')\n"
            c += "yield :_parent\n"
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end