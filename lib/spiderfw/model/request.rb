require 'spiderfw/model/model_hash'

module Spider; module Model
    
    # The request object specifies which data is to be loaded for a model. It is similar in purpose to
    # the SELECT ... part of an SQL query.
    
    class Request < ModelHash
        # @return [bool] if true, the total number of rows returned by the query is requested.
        attr_accessor :total_rows
        # @return [bool] find also the given subclasses of the queried model.
        attr_reader :polymorphs
        # @return [bool] if true, the request will be expanded with lazy groups on load
        attr_accessor :expandable
        
        # @param [Array|Hash] value Value to initialize the Request with. May be a Hash, or an Array of elements.
        # @param [Hash] params Params may have:
        #                      * :total_rows  Request the total rows corresponding to the Query from the storage
        def initialize(val=nil, params={})
            if (val.is_a?(Array))
                super()
                val.each{ |v| request(v) }
            else
                super(val)
            end
            @total_rows = params[:total_rows]
            @polymorphs = {}
            @expandable = true
        end

        # Initializes a Request that should not be expanded by the Mapper
        # @param [Array|Hash] val
        # @param [Hash] params
        # @return [Request]
        def self.strict(val=nil, params={})
            r = self.new(val, params)
            r.expandable = false
            r
        end
        
        # @param [Element|String|Symbol] Element to request
        # @return [void]
        def request(element) # :nodoc:
            if element.is_a?(Element)
                self[element.name.to_s] = true
            elsif element.is_a?(String)
                element.split(',').each do |el|
                    self[el.strip] = true
                end
            else
                self[element] = true
            end
        end
        
        # Requests that the mapper looks for subclasses of the given type, loading
        # additional subclass specific elements specified in the request
        # @param [Class<BaseModel] type The subclass
        # @param [Request] request Request for subclass specific elements
        def with_polymorphs(type, request)
            @polymorphs[type] = request
        end
        
        # @return [bool] True if there are requested polymorphs
        def polymorphs?
            @polymorphs.empty? ? false : true
        end
        
        # Requests that only the subclasses requested with {#with_polymorphs} are returned,
        # not the mapper's base class
        # @return [self]
        def only_polymorphs
            @only_polymorphs = true
            return self
        end

        # @return [bool] True if only polymorphs should be returned
        def only_polymorphs?
            @only_polymorphs
        end
        
        # Requests that the mapper retrieves also objects belonging to the model's superclass
        # @return [self] 
        def with_superclass
            @with_superclass = true
            return self
        end
        
        # @return [bool] true if the superclass was requested with {#with_superclass}
        def with_superclass?
            @with_superclass
        end


        # @return [bool] true if the Request can be expanded by the mapper (using lazy groups)
        def expandable?
            @expandable
        end
    
    end


end; end