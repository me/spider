module Spider; module Forms
    
    class CheckboxList < Input
        tag 'checkbox_list'
        i_attr_accessor :model
        is_attr_accessor :multiple
        is_attr_accessor :condition
        attribute :tree_element, :default => nil
        attr_accessor :data
        
        def widget_init(action='')
            super
            @model = const_get_full(@model) if @model.is_a?(String)
        end
        
        def prepare_scene(scene)
            scene = super
            scene.value_param = "#{scene.name}[value]"
            scene.value_param += '[]' if @multiple
            return scene
        end
        
        def prepare_value(p)
            if (p && p['value'])
                p['value']
            elsif p.is_a?(Hash)
                nil
            else
                p
            end
        end
        
        def prepare
            
            super
        end

        def run
            
            @scene.data = @data || @model.all
            if @condition
                @scene.data.condition = @condition
            end
            conn_cond = connection_condition
            if conn_cond == false
                @scene.data = Spider::Model::QuerySet.static(@model)
            elsif conn_cond && !conn_cond.empty?
                @scene.data.condition.and(conn_cond)
            end
            @scene.values = {}
            @scene.selected = {}
            if @model || (@scene.data.is_a?(QuerySet) && @scene.data.autoload?)
                tree_el = nil
                if attributes[:tree_element]
                    tree_el = @model.elements[attributes[:tree_element]]
                else
                    tree_el = @model.elements_array.select{ |el| el.association == :tree }.first
                end
                if tree_el
                    @scene.data = @scene.data.model.send("#{tree_el.name}_all", @scene.data.condition)
                    @scene.data.reject!{ |obj| obj == @form.obj } if @form && @form.obj
                    @scene.tree_depth = tree_el.attributes[:tree_depth]
                end
            end
            if @value
                val = @multiple ? @value : [@value]
                val.each do |v|
                    @scene.selected[@model.primary_keys.map{|k| v.get(k) }.join(',')] = true
                end
            end
            @scene.data.each_index do |i|
                @scene.values[i] = @model.primary_keys.map{|k| @scene.data[i][k] }.join(',')
            end
            super
        end

        
        def value=(val)
            if (val.nil? || (val.is_a?(String) && val.empty?))
                @value = nil
                return
            end
            if (val.is_a?(@model) || val.is_a?(Spider::Model::QuerySet))
                return super
            else
                if (@multiple)
                    val = [val] unless val.is_a?(Array)
                    qs = Spider::Model::QuerySet.static(@model)
                    val.each do |v|
                        obj = @model.new(str_to_pks(v))
                        qs << obj
                    end
                    return super(qs)
                else
                    return super(@model.new(str_to_pks(val)))
                end
            end
        end
        
        def obj_to_key_str(obj)
            @model.primary_keys.map{|k| obj.get(k) }.join(',')
        end
        
        def str_to_pks(val)
            if (val.is_a?(String))
                parts = val.split(',')
                pk = {}
                @model.primary_keys.each{ |k| pk[k.name] = parts.shift}
            else
                pk = val
            end
            return pk
        end
        
        def connection_condition
            if (@connections && @form)
                conn_cond = Spider::Model::Condition.and
                conn_param = params['connected'] || {}
                @connections.each do |el, conn|
                    val = @form.inputs[el].value
                    val = conn_param[el.to_s] if (conn_param[el.to_s])
                    return false if (conn[:required] && !val)
                    next unless val
                    conn_cond.set(conn[:target], '=', val)
                end
                return conn_cond
            end
            return nil
        end



    end



end;end