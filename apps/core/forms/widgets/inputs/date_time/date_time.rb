module Spider; module Forms
    
    class DateTime < Input
        tag 'datetime'
        is_attr_accessor :size, :type => Fixnum, :default => nil
        is_attr_accessor :mode, :type => Symbol, :default => :date
        i_attr_accessor :format, :type => String
        i_attr_accessor :lformat, :type => Symbol, :default => :short
        
        def prepare_value(val)
            return val if val.respond_to?(:strftime)
            return nil unless val.is_a?(String) && !val.empty?
            klass = @mode == :date ? ::Date : ::DateTime
            begin
                return klass.lparse(val)
            rescue => exc
                add_error(_("%s is not a valid date") % val)
            end
        end
        
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
            return '' unless @value
            if (@lformat && @value.respond_to?(:lformat))
                return @value.lformat(@lformat)
            elsif @format && @value.respond_to?(:strftime)
                return @value.strftime(@format)
            else
                return @value
            end
            return @value unless @value.respond_to?(:strftime)
            return @value.strftime("%d/%m/%Y %H:%M") if @value
            return ''
        end

    end
    
end; end