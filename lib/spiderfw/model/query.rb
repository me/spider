require 'spiderfw/model/condition'
require 'spiderfw/model/request'

module Spider; module Model
    
    # The Query combines a Condition and a Request, offering convenience methods and allowing
    # to further specify how the data should be returned.
    
    class Query
        # An array of element-direction (:asc or :desc) pairs
        # @return [Array]
        attr_accessor :order
        # Skip the first :offset objects
        # @return [Fixnum]
        attr_accessor :offset
        # Limit the returned results to :limit objects
        # @return [Fixnum]
        attr_accessor :limit
        # Requests subclasses of the queried model
        # @return [Array]
        attr_accessor :polymorphs
        # The Condition instance
        # @return [Condition]
        attr_reader :condition
        # The Request instance
        # @return [Request]
        attr_reader :request
        # @return [Fixnum] number of rows per page, when using pagination
        attr_reader :page_rows
        # @return [Fixnum] current page, when using pagination
        attr_reader :page
        # @return [Array] Elements the mapper has to group_by
        attr_accessor :group_by_elements
        
        # Instantiates a new query, calling Condition#where on the condition.
        # See {Query#new} for arguments
        # Return #{Condition}
        def self.where(*params)
            return self.class.new.condition.where(*params)
        end
       
       # Parameters are a Condition and a Request. If a block is given, it will be parsed by the Condition.
       # @param [Condition] condition
       # @param [Request] request
       # @param [Proc] proc Optional block used to construct the Condition
       def initialize(condition = nil, request=nil, &proc)
           @condition = condition.is_a?(Condition) ? condition : Condition.new(condition)
           @request = request.is_a?(Request) ? request : Request.new(request)
           @polymorphs = []
           @order = []
           if (proc)
               @condition = Condition.new(&proc)
           end
       end
       
       # Sets the condition. If val is not a Condition, will attempt to convert it to one
       # (val will be passed to {Condition.new}).
       # @param [Condition|Object]
       # @return [void]
       def condition=(val)
           if (!val.is_a?(Condition))
               @condition = Condition.new(val)
           else
               @condition = val
           end
       end
       
       # Sets the request. If val is not a Request, will attempt to convert it to one
       # (val will be passed to {Request.new}).
       # @param [Request|Object]
       # @return [void]
       def request=(val)
           if (!val.is_a?(Request))
               @request = Request.new(val)
           else
               @request = val
           end
       end
       
       # Sets required oreder.
       # Arguments can be:
       # * an element-direction pair, or
       # * a list of 'element direction' strings, or
       # * a list of elements (:asc direction will be implied).
       # Example:
       #   query.order_by(:element, :desc)
       #   query.order_by('name desc', :rating)
       # @param [*Symbol|String] elements A list of elements
       # @return [self]
       def order_by(*elements)
           if (elements.length == 2 && [:asc, :desc].include?(elements[1]))
               @order << elements
               return self
           end
           elements.each do |l|
               if (l.is_a?(String))
                   parts = l.split(' ')
                   name = parts[0]
                   order = parts[1]
               else
                   parts = [l, :asc]
               end
               raise "Order elements must be strings or symbols" unless parts[0].is_a?(String) || parts[0].is_a?(Symbol)
               @order << [parts[0], parts[1]]
           end
           return self
       end

       # Elements to group_by (used by some mappers for aggregate queries)
       # @param [*Symbol|String] elements A list of elements
       # @return [self]
       def group_by(*elements)
           @group_by_elements ||= []
           @group_by_elements += elements
           return self
       end
       
       # Adds each element in the given list to the request.
       # @param [*Symbol|String] elements A list of elements
       # @return [self]
       def select(*elements)
           elements.each do |element|
               @request.request(element.to_s)
           end
           return self
       end
       
       # Takes an argument or a block.
       # If given an argument, will use it as a Condition. If given a block, will use it on the Condition.
       # @param [Condition] condition
       # @param [Proc] proc Block used to construct the Condition
       def where(condition=nil, &proc)
           condition = Condition.new(&proc) unless (condition)
           @condition << condition
           return self
       end
       
       # Requests a polymorph. This means that the mapper will try to differentiate the result into 
       # the subclasses given here.
       # @param [Class<BaseModel] type The polymorph class to look for
       # @param [Request] request Additional elements of the subclass to request
       # @return [self]
       def with_polymorph(type, request=nil)
           query = self.class.new(query) unless query.is_a?(self.class)
           @polymorphs << type
           unless request
               request = Request.new
               type.primary_keys.each{ |k| request[k.name] = true }
           end
           @request.with_polymorphs(type, request)
           return self
       end
       
       # Requests only polymorphs. (see Request#only_polymorphs).
       # @return [Request]
       def only_polymorphs
           @request.only_polymorphs
       end
       
       # Load also objects that belong to the superclass, and don't have this subclass.
       # See #Request#with_superclass.
       # @return [Request]
       def with_superclass
           @request.with_superclass
       end
       
       # Request only the first result.
       # @return [void]
       def only_one
           self.limit = 1
           @only_one = true
       end

       # @return [bool] Was only the first record requested?
       def only_one?
           @only_one
       end
       
       # Pagination: request the given page, for given rows per page
       # @param [Fixnum] page
       # @param [Fixnum] rows
       # @return [self]
       def page(page, rows)
           page = page.to_i
           page = 1 if page == 0
           @page_rows = rows
           @page = page
           offset = ((page - 1) * rows)
           self.limit = rows
           self.offset = offset
           self
       end
       
       ##############################
       # information methods        #
       ##############################
       
       # @return [bool] Are there requested polymorphs?
       def polymorphs?
           @polymorphs.length > 0
       end
       
       # Returns a deep copy.
       # @return [Query]
       def clone
           cl = self.class.new(@condition.clone, @request.clone)
           cl.order = @order.clone
           cl.offset = @offset
           cl.limit = @limit
           cl.polymorphs = @polymorphs.clone
           cl.group_by_elements = @group_by_elements.clone if @group_by_elements
           return cl
       end
       
       
        
    end
    

    
end; end
