module Spider
    
    class WidgetAttributes < Hash
        
        def initialize(widget)
            @widget = widget
            @attributes = widget.class.attributes
            @attributes.each do |k, params|
                if params[:default]
                    if (params[:default].is_a?(Proc))
                        self[k] = params[:default].call
                    else
                        self[k] = params[:default]
                    end
                end
            end
        end
        
        def []=(k, v)
            params = @attributes[k]
            raise ArgumentError, "#{k} is not an allowed attribute for widget #{@widget}" unless params
            raise ArgumentError, "#{k} is not in the correct format" if params[:format] && v !=~ params[:format]
            if (params[:type])
                case params[:type].name
                when 'String'
                    v = v.to_s
                when 'Symbol'
                    v = v.to_sym if v
                when 'TrueClass', 'FalseClass', 'Spider::DataTypes::Bool'
                    v = (v.to_s == 'false' || v.to_s.empty?) ? false : true
                when 'Fixnum'
                    v = v.to_i
                end
            end
            v = params[:process].call(v) if params[:process] && v
            @widget.instance_variable_set("@#{params[:ruby_name]}", v) if params[:set_var]
            super(k, v)
        end
        
        def [](k)
            return nil unless @attributes[k]
            params = @attributes[k]
            v = super
            if (!v)
                return @widget.instance_variable_get("@#{params[:ruby_name]}") if params[:instance_attr]
                return nil
            end
            return v
        end
        
        
    end
    
end
