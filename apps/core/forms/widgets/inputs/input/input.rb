module Spider; module Forms
    
    class Input < Spider::Widget
        attr_accessor :form, :errors
        i_attr_accessor :name
        is_attribute :value
        is_attr_accessor :label
        
        def self.template_path_parent
            File.dirname(File.dirname(__FILE__))
        end
        
        def init
            @done = true
            @errors = []
            @modified = true
        end
        
        def prepare_scene(scene)
            scene = super
            scene.name = @name || '_w'+param_name(self)
            scene.formatted_value = format_value
            return scene
        end
        
        def prepare_value(val)
            val == {} ? nil : val
        end
        
        def prepare
            prepared = prepare_value(params)
            self.value = prepared if prepared
            super
        end
        
        def value
            @value
        end
        
        def value=(val)
            @value = val
        end
        
        def format_value
            @value
        end
        
        def done?
            @done
        end
        
        def error?
            @error
        end
        
        def add_error(str)
            @errors << str
            @error = true
        end
        
        def modified?
            @modified
        end
        
        def read_only
            @read_only = true
            if template_exists?(@use_template+'_readonly')
                @use_template += '_readonly'
            elsif template_exists?('readonly')
                @use_template = 'readonly'
            else
                @use_template = 'SPIDER/apps/core/forms/widgets/inputs/input/readonly'
            end
        end
        
        def read_only?
            @read_only
        end
        
        
        # def execute
        #     @scene.name = 
        #     @scene.value = @value
        # end
            
        
    end
    
end; end