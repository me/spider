require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Recurse < Block
        
        def compile(options={})
            init = ""
            c = ""
            lambda_name = @el.attributes['lambda']
            vars_attr = @el.attributes['vars']
            vars = nil
            unless vars_attr.blank?
                vars = {}
                var_pairs = vars_attr.split(/\s*,\s*/)
                var_pairs.each do |pair|
                    from, to = pair.split(/\s*=>\s*/)
                    vars[from] = to
                end
                c += "___prev_vars = {}\n"
                vars.each do |from, to|
                    c += "___prev_vars[:#{from}] = #{from}\n"
                end
                vars.each do |from, to|
                    c += "#{from} = #{to}\n"
                end
            end
            c += "#{lambda_name}.call\n"
            if vars
                vars.each do |from, to|
                    c += "#{from} = ___prev_vars[:#{from}]\n"
                end
            end            
            return CompiledBlock.new(init, c)
        end
        
        
    end
    
    
end; end