module Spider; module Forms
    
    class DateTime < Input
        tag 'datetime'
        is_attr_accessor :size, :type => Fixnum, :default => 15
        
        def format_value
            return @value.strftime("%d/%m/%Y %H:%M") if @value
            return ''
        end

    end
    
end; end