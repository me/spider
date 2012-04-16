module Spider; module Forms
    
    class Input < Spider::Widget
        attr_accessor :element, :form, :errors
        i_attr_accessor :name
        is_attribute :value
        is_attr_accessor :default
        is_attr_accessor :label
        is_attr_accessor :required, :type => Spider::DataTypes::Bool

        
        
        def init
            @done = true
            @errors = []
            @modified = true
            @connections = {}
        end
        
        def prepare_scene(scene)
            scene = super
            scene.name = @name || '_w'+param_name(self)
            scene.formatted_value = format_value
            return scene
        end
        
        # Returns the value to be stored. If nil is returned, the value will not be unset; in this case,
        # the method should modify the value directly.
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
            @value ||= @default
            @value.respond_to?(:format) ? @value.format : @value
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
        
        def has_value?
            @value && (!@value.is_a?(String) || !@value.empty?)
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
        
        def required?
            @attributes[:required]
        end
        
        def check
            #debugger
            if required? && !has_value?
                Spider::GetText.in_domain(self.class.app.gettext_domain){
                    add_error( _("%s is required") % self.label )    
                }
            end
        end
        
        def parse_runtime_content(doc, src_path=nil)
            doc = super
            doc.search('input:connect').each do |connect|
                options = {}
                options[:required] = connect.attributes['required'] ? true : false
                connect(connect.attributes['element'].to_sym, connect.attributes['target'].to_sym, options)
            end
        end
        
        def connect(element_name, target, options)
            @connections[element_name] = ({
              :target => target  
            }).merge(options)
            @css_classes << "connect-#{target}"
        end
        
        def needs_multipart?
            false
        end
        
        
        # def execute
        #     @scene.name = 
        #     @scene.value = @value
        # end
            
        
    end
    
end; end