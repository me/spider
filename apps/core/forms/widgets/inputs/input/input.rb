module Spider; module Forms
    
    class Input < Spider::Widget
        attr_accessor :form
        i_attr_accessor :name
        is_attr_accessor :value
        is_attr_accessor :label
        
        def self.template_path_parent
            File.dirname(File.dirname(__FILE__))
        end
        
        def init
            @done = true
        end
        
        def prepare_scene(scene)
            scene = super
            scene.name = @name || '_w'+param_name(self)
        end
        
        def prepare_value(val)
            val
        end
        
        def prepare
            v = prepare_value(params)
            self.value = v if v != {}
        end
        
        # def name
        #     @name || param_name(self)
        # end
        
        def value
            @value
        end
        
        def done?
            @done
        end
        
        
        # def execute
        #     @scene.name = 
        #     @scene.value = @value
        # end
            
        
    end
    
end; end