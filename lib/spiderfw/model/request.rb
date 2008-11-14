require 'spiderfw/model/model_hash'

module Spider; module Model
    
    class Request < ModelHash
        
        def initialize(val=nil)
            if (val.is_a?(Array))
                super()
                val.each{ |v| request(v) }
            else
                super
            end
        end
        
        def request(element)
            element.to_s.split(',').each do |el|
                self[el.strip] = true
            end
        end
    
        def load_all_simple
            @load_all_simple = true
        end
        
        def load_all_simple?
            @load_all_simple
        end
    
    end


end; end