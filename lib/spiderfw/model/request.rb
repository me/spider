require 'spiderfw/model/model_hash'

module Spider; module Model
    
    class Request < ModelHash
        attr_accessor :total_rows
        attr_reader :polymorphs
        
        def initialize(val=nil, params={})
            if (val.is_a?(Array))
                super()
                val.each{ |v| request(v) }
            else
                super(val)
            end
            @total_rows = params[:total_rows]
            @polymorphs = {}
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
        
        def with_polymorphs(type, request)
            @polymorphs[type] = request
        end
    
    end


end; end