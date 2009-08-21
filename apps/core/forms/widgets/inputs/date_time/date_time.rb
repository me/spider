module Spider; module Forms
    
    class DateTime < Input
        tag 'datetime'
        is_attr_accessor :size, :type => Fixnum, :default => nil
        is_attr_accessor :mode, :type => Symbol, :default => :date
        
        def prepare
            unless @size
                @size = case @mode
                when :date then 10
                when :date_time then 15
                when :time then 8
                end
            end
            super
        end
        
        def format_value
            return '' unless @value.respond_to?(:strftime)
            return @value.strftime("%d/%m/%Y %H:%M") if @value
            return ''
        end

    end
    
end; end