module Spider; module Components
    
    class Confirm < Spider::Widget
        tag 'confirm'
        is_attr_accessor :actions
        is_attribute :cancel_param
        is_attribute :ok_param
        is_attribute :cancel_text, :default => lambda{ _('Cancel') }
        is_attribute :ok_text, :default => lambda{ _('Ok') }

        
        def prepare
            @scene.params = collapse_params(@request.params)
            unless @actions
                @cancel_param ||= '_w'+param_name(self)+'[cancel]'
                @ok_param ||= '_w'+param_name(self)+'[ok]'
                add_action(@cancel_param, @cancel_text)
                add_action(@ok_param, @ok_text)
             end
        end
        
        def add_action(name, value, type=nil)
            @actions ||= []
            @actions << [name, value, type]
        end
        
        def collapse_params(h, first=true)
            res = []
            h.each do |k, v|
                res_key = first ? k : "[#{k}]"
                case v
                when Hash
                    collapse_params(v, false).each do |v_k, v_v|
                        res << ["#{res_key}#{v_k}", v_v]
                    end
                when Array
                    # NOTE: doesn't handle arrays of Hashes and arrays of Arrays
                    v.each do |v_v|
                        res << ["#{res_key}[]", v_v]
                    end
                else
                    res << [res_key, v]
                end
            end
            return res
        end
        
    end
    
end; end