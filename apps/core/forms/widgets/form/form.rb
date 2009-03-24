module Spider; module Forms
    
    class Form < Spider::Widget
        tag 'form'
        is_attribute :action
        i_attribute :model
        attribute :submit_text, :default => _('Submit')
        is_attr_accessor :pk
        attr_to_scene :inputs, :elements, :labels, :error, :errors
        
        attr_accessor :pk
        attr_reader :obj
        
        def init
            @inputs = {}
            @elements = []
            @errors = {}
            @labels = {}
        end
        
        def prepare
            @action = @request.path
            @pk = params['pk'] if params['pk']
            @model.each_element do |el|
                @labels[el.name] = el.label
            end
            @data = params['data'] || {}
            debug("FORM DATA:")
            debug(@data)
        end
        
        def start
            create_inputs
            debug("FORM executing")
            save if params['submit']
            @obj = load
            set_values(@obj) if (@obj)
            @scene.submit_text = @attributes[:submit_text]
        end
        
        def create_inputs
            @model.each_element do |el|
                next if el.hidden? || el.primary_key? || el.attributes[:local_pk]
                input = nil
                if (el.type == String || el.type == Fixnum)
                    input = create_widget(Text, el.name, @request, @response)
                    input_attributes = {:size => 5} if (el.type == Fixnum)
                elsif (el.model? && [:choice, :multiple_choice].include?(el.association))
                    input = create_widget(Select, el.name, @request, @response)
                    input.multiple = true if el.multiple?
                    input.model = el.model
                end
                if (input)
                    @elements << el.name
                    input.id = el.name
                    input.name = '_w'+param_name(input.id_path[0..-2]+['data']+input.id_path[-1..-1])
                    input.label = @labels[el.name]
                    @inputs[el.name] = input
                    if (input_attributes)
                        @widget_attributes[input.id] ||= {}
                        @widget_attributes[input.id] = input_attributes.merge(@widget_attributes[input.id])
                    end
                end
            end
        end
        
        def set_values(obj)
            @inputs.each do |element_name, input|
                input.value = @data[element_name.to_s] || obj.get(element_name)
            end
        end
        
        def instantiate_obj
            if (@pk)
                parts = @pk.split(',')
                h = {}
                @model.primary_keys.each{ |k| h[k.name] = parts.shift}
                return @model.new(h)
            else
                return @model.new
            end
        end
        
        def load
            instantiate_obj if (@pk)
        end
        
        def save
            obj = instantiate_obj
            @error = false
            @elements.each do |element_name|
                debug("SETTING #{element_name} TO #{@inputs[element_name].prepare_value(@data[element_name.to_s])}")
                begin
                    obj.set(element_name, @inputs[element_name].prepare_value(@data[element_name.to_s]))
                rescue FormatError => exc
                    @error = true
                    @errors[element_name] ||= []
                    @errors[element_name] << exc.message
                end
            end
            unless @error
                obj.save
                debug("SAVED")
                @saved = true
                @pk = @model.primary_keys.map{ |k| obj[k.name] }.join(',')
            end
        end
        
        def saved?
            @saved
        end
        
        def error?
            @error
        end
        
        
    end
    
end; end