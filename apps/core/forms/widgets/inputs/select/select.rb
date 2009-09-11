module Spider; module Forms
    
    class Select < Input
        tag 'select'
        i_attr_accessor :model
        is_attr_accessor :multiple
        is_attr_accessor :blank_option, :type => TrueClass, :default => true
        is_attr_accessor :condition
        attr_accessor :data
        
        def prepare_scene(scene)
            scene = super
            scene.name += '[]' if @multiple
            return scene
        end
        
        def run
            @scene.data = @data || @model.all
            if (@condition)
                @scene.data.condition = @condition
            end
            @scene.values = {}
            debug("SELECT VALUE:")
            debug(@value)
            @scene.selected = {}
            if (@value)
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
            debug("SETTING SELECT VALUE TO")
            debug(val)
            return if (val.nil? || (val.is_a?(String) && val.empty?))
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
    
end; end