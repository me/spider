module Spider; module Forms
    
    class Checkbox < Input
        tag 'checkbox'
        
        def prepare_value(val)
            val = super
            return val ? true : false
        end

    end
    
end; end