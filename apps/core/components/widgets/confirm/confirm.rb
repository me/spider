module Spider; module Components
    
    class Confirm < Spider::Widget
        tag 'confirm'
        is_attr_accessor :actions
        
        def prepare
            @scene.params = collapse_params(@request.params)
            if (!@actions)
                add_action('_w'+param_name(self)+'[cancel]', 'Cancel')
                add_action('_w'+param_name(self)+'[ok]', 'Ok')
             end
        end
        
        def add_action(name, value, type=nil)
            @actions ||= []
            @actions << [name, value, type]
        end
        
        def collapse_params(h, first=true)
            res = {}
            h.each do |k, v|
                res_key = first ? k : "[#{k}]"
                if (v.is_a?(Hash))
                    collapse_params(v, false).each do |v_k, v_v|
                        res["#{res_key}#{v_k}"] = v_v
                    end
                else
                    res[res_key] = v
                end
            end
            return res
        end
        
    end
    
end; end