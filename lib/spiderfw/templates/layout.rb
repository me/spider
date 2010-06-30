module Spider
    
    class Layout < Template
#        allow_blocks :HTML, :Text, :Render, :Yield, :If, :TagIf, :Each, :Pass, :Widget
        attr_accessor :template
        
        def init(scene)
            super
            @template = @template.is_a?(Template) ? @template : Template.new(@template)
            @template.init(scene) unless @template.init_done?
            
        end
        
        def render(*args)
            prepare_assets unless @assets_prepared
            super
        end
        
        def prepare_assets
            @template_assets = {:css => [], :js => []}
            seen = {}
            all_assets.each do |res|
                next if seen[res[:src]]
                seen[res[:src]] = true
                @template_assets[res[:type].to_sym] ||= []
                @template_assets[res[:type].to_sym] << res[:src]
            end
            @content[:yield_to] = @template
            @scene.assets = @template_assets
            @assets_prepared = true
        end
        
        @@named_layouts = {}
        
        class << self
            
            def register_layout(name, file)
                @@named_layouts[name] = file
            end
            
            def named_layouts
                @@named_layouts
            end
            
        end
        
        def all_assets
            return @template.assets + self.assets
        end
        
        end

        
    end
    
end