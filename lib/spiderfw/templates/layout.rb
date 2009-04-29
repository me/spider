module Spider
    
    class Layout < Template
#        allow_blocks :HTML, :Text, :Render, :Yield, :If, :TagIf, :Each, :Pass, :Widget
        attr_accessor :template
        
        def init(scene)
            super
            @template = @template.is_a?(Template) ? @template : Template.new(@template)
            @template.init(scene) unless @template.init_done?
            @template.prepare_sub unless @template.prepare_sub_done?
            @template.init_sub unless @template.init_sub_done?
            @template_resources = {:css => [], :js => []}
            @template.all_resources.each do |res|
                @template_resources[res[:type].to_sym] ||= []
                @template_resources[res[:type].to_sym] << res[:src]
            end
            @content[:yield_to] = @template
            scene.resources = @template_resources
        end

        
    end
    
end