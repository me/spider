module Spider
    
    class WidgetAttributes < Hash
        
        def initialize(widget_klass)
            @widget_klass = widget_klass
            @attributes = widget_klass.attributes
        end
        
        def []=(k, v)
            params = @attributes[k]
            raise ArgumentError, "#{k} is not an allowed attribute for widget #{@widget_klass}" unless params
            raise ArgumentError, "#{k} is not in the correct format" if params[:format] && v !=~ params[:format]
            if (params[:type])
                case params[:type].name
                when 'String'
                    v = v.to_s
                when 'Symbol'
                    v = v.to_sym
                when 'TrueClass', 'FalseClass'
                    v = v.to_s == 'false' ? false : true
                end
            end
            v = params[:process].call(v) if params[:process] && v
            super(k, v)
        end
        
        
    end
    
end