module Spider; module Forms
    
    class Select < Input
        tag 'select'
        i_attr_accessor :model
        is_attr_accessor :multiple
        is_attr_accessor :blank_option, :type => TrueClass, :default => true
        
        def execute
            @scene.data = @model.all
            @scene.values = {}
            debug("SELECT VALUE:")
            debug(@value)
            if (@value)
                @scene.value_pks = @model.primary_keys.map{|k| @value.get(k) }.join(',')
            end
            @scene.data.each_index do |i|
                @scene.values[i] = @model.primary_keys.map{|k| @scene.data[i][k] }.join(',')
            end
            
        end

        
        def value=(val)
            debug("SETTING SELECT VALUE TO")
            debug(val)
            return if (val.nil? || (val.is_a?(String) && val.empty?))
            if (val.is_a?(@model))
                return super
            else
                if (val.is_a?(String))
                    parts = val.split(',')
                    pk = {}
                    @model.primary_keys.each{ |k| pk[k.name] = parts.shift}
                else
                    pk = val
                end
                return super(@model.new(pk))
            end
        end

    end
    
end; end