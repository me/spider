module Spider; module Forms
    
    class Form < Spider::Widget
        tag 'form'
        is_attribute :form_action
        i_attribute :model
        i_attribute :elements
        i_attribute :widget_types
        i_attribute :read_only
        i_attribute :disabled
        attribute :save_submit_text, :default => _('Save')
        attribute :insert_submit_text, :default => _('Insert')
        is_attr_accessor :pk
        attr_to_scene :inputs, :names, :labels, :error, :errors, :save_errors, :sub_links
        attr_accessor :save_actions
        attr_accessor :fixed
        
        attr_accessor :pk
        attr_reader :obj
        
        def init
            @inputs = {}
            @names = []
            @errors = {}
            @save_errors = []
            @labels = {}
            @save_actions ||= {}
            @sub_links = {}
        end
        
        def route_widget
            if (@action == :sub)
                [:crud, @_action.split('/', 3)[2]]
            end
        end
        
        def prepare(action='')
            @form_action = @request.path
            @pk = @_action_local
            @pk = nil if @pk == 'new'
            @model = const_get_full(@model) if @model.is_a?(String)
            if (@elements.is_a?(String))
                @elements = @elements.split(',').map{ |e| debug("EL: #{e.strip.to_sym}"); @model.elements[e.strip.to_sym] }.reject{ |i| i.nil? }
            end
            @elements = @model.elements_array unless @elements
            @model.each_element do |el|
                @labels[el.name] = el.label
            end
            wt = @widget_types || {}
            @widget_types = {}
            wt.each do |key, value|
                value = const_get_full(value) if value.is_a?(String)
                @widget_types[key.to_sym] = value
            end
            if (@read_only.is_a?(String))
                @read_only = @read_only.split(',').map{ |el| e.strip.to_sym }
            end
            @read_only ||= []
            if (@disabled.is_a?(String))
                @disabled = @disabled.split(',').map{ |el| e.strip.to_sym }
            end
            @disabled ||= []
            @data = params['data'] || {}
            if @_action_rest
                el_label, sub_rest = @_action_rest.split('/', 2)
                sub_rest ||= ''
                @sub_element = @elements.find{ |el| el.label.downcase.gsub(/\s+/, '_') == el_label}
            end
            if (@sub_element)
                @action = :sub
                @scene.sub_element = @sub_element
                @_pass_action = sub_rest
            else
                @action = :form
            end
            @scene.action = @action
            super
        end
        
        def prepare_widgets
            if (@action == :sub)
                @widgets[:crud] = Spider::Components::Crud.new(@request, @response)
                @widgets[:crud].id = (@model.name.to_s+'_'+@sub_element.name.to_s).gsub('::', '_').downcase
                @widgets[:crud].model = @sub_element.model
                @scene.crud = @widgets[:crud]
                @obj = load
                cond = {}
                @model.primary_keys.each do |key|
                    cond[@sub_element.reverse.to_s+'.'+key.name.to_s] = @obj.get(key)
                end
                @widgets[:crud].fixed = cond
            else
                create_inputs
            end
            super
        end
        
        def run
            Spider::Logger.debug("FORM EXECUTING")
            save(params['submit']) if params['submit']
            @obj ||= load
            if (@obj)
                @fixed.each {|k, v| @obj.set(k, v)} if (@fixed)
                @scene.form_desc = @model.label.downcase+' '+ @obj.to_s
                set_values(@obj) if @action == :form
                if (@action == :sub)
                    
                end
                @scene.submit_text = @attributes[:save_submit_text]
            else
                @scene.submit_text = @attributes[:insert_submit_text]
            end
            @scene.submit_buttons = @save_actions.keys
            super
        end
        
        def create_inputs
            @elements.each do |el|
                next if el.hidden? || el.primary_key? || el.attributes[:local_pk] || @disabled.include?(el.name)
                input = nil
                widget_type = nil
                if (@widget_types[el.name])
                    widget_type = @widget_types[el.name]
                elsif (el.type == String || el.type == Fixnum)
                    widget_type = Text
                    input_attributes = {:size => 5} if (el.type == Fixnum)
                elsif (el.type == Float || el.type == BigDecimal || el.type == Spider::DataTypes::Decimal)
                    widget_type = Text
                    input_attributes = {:size => 10}
                elsif (el.type == Spider::DataTypes::Text)
                    widget_type = TextArea
                elsif (el.type == ::DateTime)
                    widget_type = DateTime
                elsif (el.type == Spider::DataTypes::Password)
                    widget_type = Password
                elsif (el.type == Spider::DataTypes::Bool)
                    widget_type = Checkbox
                elsif (el.model?)
                    if ([:choice, :multiple_choice].include?(el.association) && !el.extended?)
                        widget_type = el.model.attributes[:estimated_size] && el.model.attributes[:estimated_size] > 100 ? 
                            SearchSelect : Select
                    elsif @pk
                        @sub_links[@pk+'/'+el.label.downcase.gsub(/\s+/, '_')] = @labels[el.name]
                    end
                end
                input = create_input(widget_type, el) if widget_type
                input.read_only if read_only?(el.name)
                debug("Created input for #{el.name}, #{input}")
                if (input)
                    input.id_path.insert(input.id_path.length-1, 'data')
                    @names << el.name
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
        
        def create_input(type, el)
            input = create_widget(type, el.name, @request, @response)
            case type.name
            when 'Spider::Forms::Select', 'Spider::Forms::SearchSelect'
                input.multiple = true if el.multiple?
                input.model = el.type
            end
            return input
        end
        
        def set_values(obj)
            @inputs.each do |element_name, input|
                debug("SET VALUE #{obj.get(element_name)} ON INPUT #{input}, #{input.object_id}")
                input.value ||= obj.get(element_name)
            end
        end
        
        def instantiate_obj
            if (@pk)
                parts = @pk.split(':')
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
        
        def save(action=nil)
            obj = instantiate_obj
            @save_actions[action].call(obj) if (action && @save_actions[action])
            @error = false
            inputs_done = true
            Spider::Logger.debug("FORM SAVING")
            Spider::Logger.debug(@elements)
            @elements.each do |el|
                break unless inputs_done
                element_name = el.name
                next if read_only?(element_name)
                input = @inputs[element_name]
                next unless input
                next if input.read_only?
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
#                        debugger
                        obj.set(element_name, input.value)
                    else
                        inputs_done = false
                    end
#                    obj.set(element_name, @inputs[element_name].prepare_value(@data[element_name.to_s]))
                rescue FormatError => exc
#                    debugger
                    @error = true
                    @errors[element_name] ||= []
                    @errors[element_name] << exc.to_s
                end
            end
            if (@fixed)
                @fixed.each do |k, v| 
                    obj.set(k, v)
                end
            end
            if inputs_done && !@error
                begin
                    obj.save_all
                    debug("SAVED")
                    @saved = true
                    @pk = @model.primary_keys.map{ |k| obj[k.name] }.join(':')
                rescue => exc
                    Spider::Logger.error(exc)
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
        
        def read_only?(element_name)
            @read_only.include?(element_name) || @model.elements[element_name].read_only?
        end
        
        def set_read_only(*names)
            @read_only += names
        end
        
        def disable(*names)
            @disabled += names
        end
        
        
    end
    
end; end