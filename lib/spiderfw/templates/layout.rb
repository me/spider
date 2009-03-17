module Spider
    
    class Layout < Template
#        allow_blocks :HTML, :Text, :Render, :Yield, :If, :TagIf, :Each, :Pass, :Widget
        attr_accessor :template
        
        def init(scene=nil)
            super
            @template = @template.is_a?(Template) ? @template : Template.new(@template)
            @template.init(scene)
            @template_resources = {:css => [], :js => []}
            @template.all_resources.each do |res|
                @template_resources[res[:type].to_sym] ||= []
                @template_resources[res[:type].to_sym] << res[:src]
            end
            scene.yield_to_template = @template
            scene.resources = @template_resources
        end
        
        # def render(scene=nil)
        #     
        #     super
        # end
        
    end
    
end