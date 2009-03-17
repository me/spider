module Spider; module Forms
    
    class Input < Spider::Widget
        is_attr_accessor :name
        is_attr_accessor :value
        is_attr_accessor :label
        
        def self.template_path_parent
            File.dirname(File.dirname(__FILE__))
        end
        
        def prepare_value(val)
            val
        end
        
        # def execute
        #     @scene.name = 
        #     @scene.value = @value
        # end
            
        
    end
    
end; end