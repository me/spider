module Spider; module Forms
    
    class CheckboxList < Input
        tag 'checkbox_list'
        i_attr_accessor :model
        is_attr_accessor :condition
        attr_accessor :data
        
        def widget_init(action='')
            super
            @model = const_get_full(@model) if @model.is_a?(String)
        end
        
        def prepare_value(p)
            return @value unless p['val']
            qs = Spider::Model::QuerySet.static(@model)
            p['val'].each do |key, value|
                if value == '1'
                    obj = @model.new(str_to_pks(key))
                    qs << obj
                end
            end
            @value = qs
            @value
        end
        
        def prepare
            super
        end

        def run
            @scene.data = @data || @model.all
            if @condition
                @scene.data.condition = @condition
            end
            @scene.values = {}
            @scene.selected = {}
            if @value
                val = @value
                val.each do |v|
                    @scene.selected[@model.primary_keys.map{|k| v.get(k) }.join(',')] = true
                end
            end
            @scene.data.each_index do |i|
                @scene.values[i] = @model.primary_keys.map{|k| @scene.data[i][k] }.join(',')
            end
            super
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
        
        
    end



end;end
