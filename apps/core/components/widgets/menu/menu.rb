module Spider; module Components
    
    class Menu < Spider::Widget
        tag 'menu'
        
        is_attr_accessor :current
        attr_to_scene :sections
        
        def init
            @sections = {}
        end
        
        def add(label, target, section=nil)
            @sections[section] ||= []
            @sections[section] << [label, target]
        end

    end
    
end; end