module Spider
    
    class Layout < Template
        allow_blocks :HTML, :Text, :Render, :Yield
        attr_accessor :template
        
        def render(scene=nil)
            scene ||= (@scene || Scene.new)
            tmpl = @template.is_a?(Template) ? @template : Template.new(@template)
            scene[:yield_to_template] = tmpl
            super
        end
        
    end
    
end