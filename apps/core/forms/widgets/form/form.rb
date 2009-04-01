module Spider; module Forms
    
    class Form < Spider::Widget
        tag 'form'
        is_attribute :action
        i_attribute :model
        attribute :save_submit_text, :default => _('Save')
        attribute :insert_submit_text, :default => _('Insert')
        is_attr_accessor :pk
        attr_to_scene :inputs, :elements, :labels, :error, :errors, :save_errors
        
        attr_accessor :pk
        attr_reader :obj
        
        def init
            @inputs = {}
            @elements = []
            @errors = {}
            @save_errors = []
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
        end
        
        def execute
            save if params['submit']
            @obj = load
            if (@obj)
                set_values(@obj) 
                @scene.submit_text = @attributes[:save_submit_text]
            else
                @scene.submit_text = @attributes[:insert_submit_text]
            end
        end
        
        def create_inputs
            @model.each_element do |el|
                next if el.hidden? || el.primary_key? || el.attributes[:local_pk]
                input = nil
                if el.read_only?
                    input = create_widget(Input, el.name, @request, @response)
                elsif (el.type == String || el.type == Fixnum)
                    input = create_widget(Text, el.name, @request, @response)
                    input_attributes = {:size => 5} if (el.type == Fixnum)
                elsif (el.type == Spider::DataTypes::Password)
                    input = create_widget(Password, el.name, @request, @response)
                elsif (el.model? && [:choice, :multiple_choice].include?(el.association) && !el.extended?)
                    klass = el.model.attributes[:estimated_size] && el.model.attributes[:estimated_size] > 100 ? 
                        SearchSelect : Select
                    input = create_widget(klass, el.name, @request, @response)
                    input.multiple = true if el.multiple?
                    input.model = el.type
                end
                if (input)
                    input.id_path.insert(input.id_path.length-1, 'data')
                    @elements << el.name
                    input.id = el.name
                    input.form = self
#                    input.name = '_w'+param_name(input.id_path[0..-2]+['data']+input.id_path[-1..-1])
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
                input.value ||= obj.get(element_name)
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
            inputs_done = true
            @elements.each do |element_name|
                break unless inputs_done
                el = @model.elements[element_name]
                next if el.read_only?
                input = @inputs[element_name]
                next unless input.modified?
                debug("SETTING #{element_name} TO #{@inputs[element_name].prepare_value(@data[element_name.to_s])}")
                if (input.error?)
                    @error = true
                    @errors[element_name] ||= []
                    @errors[element_name] += input.errors
                    next
                end
                begin
                    if (input.done?)
                        obj.set(element_name, input.value)
                    else
                        inputs_done = false
                    end
#                    obj.set(element_name, @inputs[element_name].prepare_value(@data[element_name.to_s]))
                rescue FormatError => exc
                    @error = true
                    @errors[element_name] ||= []
                    @errors[element_name] << exc.message
                end
            end
            if inputs_done && !@error
                begin
                    obj.save
                    debug("SAVED")
                    @saved = true
                    @pk = @model.primary_keys.map{ |k| obj[k.name] }.join(',')
                rescue => exc
                    @error = true
                    @save_errors << exc.message
                end
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