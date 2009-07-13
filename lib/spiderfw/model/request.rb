require 'spiderfw/model/model_hash'

module Spider; module Model
    
    # The request object specifies which data is to be loaded for a model. It is similar in purpose to
    # the SELECT ... part of an SQL query.
    
    class Request < ModelHash
        # (bool) if true, the total number of rows returned by the query is requested.
        attr_accessor :total_rows
        # (array) find also the given subclasses of the queried model.
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
        
        # TODO: fix/remove?
        def request(element) # :nodoc:
            if (element.is_a?(Element))
                self[element.name.to_s] = true
            else
                element.to_s.split(',').each do |el|
                    self[el.strip] = true
                end
            end
        end
    
        # Requests all base types
        def load_all_simple
            @load_all_simple = true
        end
        
        def load_all_simple?
            @load_all_simple
        end
        
        # Adds a request for a subclass.
        def with_polymorphs(type, request)
            @polymorphs[type] = request
        end
        
        def polymorphs?
            @polymorphs.empty? ? false : true
        end
        
        # Requests only subclasses, not the queried model.
        def only_polymorphs
            @only_polymorphs = true
        end
        
        def only_polymorphs?
            @only_polymorphs
        end
    
    end


end; end