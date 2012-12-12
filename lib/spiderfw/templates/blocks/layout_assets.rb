require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class LayoutAssets < Block
        
        def compile(options={})
            init = ""
            c = ""
            type = @el.get_attribute('type') || 'nil'
            prefix = @el.get_attribute('prefix')
            c += "output_assets"
            c+= "(:#{type}"
            c += ", :prefix => '#{prefix}'" if prefix
            c += ")"
            c += "\n"
            return CompiledBlock.new(init, c)
        end

    end
    
    
end; end