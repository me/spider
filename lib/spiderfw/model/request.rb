require 'spiderfw/model/model_hash'

module Spider; module Model
    
    class Request < ModelHash
        
        def request(element)
            element.split(',').each do |el|
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