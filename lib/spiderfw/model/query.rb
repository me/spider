require 'spiderfw/model/condition'
require 'spiderfw/model/request'

module Spider; module Model
    
    # The Query combines a Condition and a Request, offering convenience methods and allowing
    # to further specify how the data should be returned.
    
    class Query
        # An array of element-direction (:asc or :desc) pairs
        attr_accessor :order
        # Skip the first :offset objects
        attr_accessor :offset
        # Limit the returned results to :limit objects
        attr_accessor :limit
        # Requests subclasses of the queried model
        attr_accessor :polymorphs
        # The Condition instance
        attr_reader :condition
        # The Request instance
        attr_reader :request
        attr_reader :page_rows
        attr_reader :page
        
        # Instantiates a new query, calling Condition#where on the condition.
        def self.where(*params)
            return self.class.new.condition.where(*params)
        end
       
       # Parameters are a Condition and a Request. If a block is given, it will be parsed by the Condition.
       def initialize(condition = nil, request=nil, &proc)
           @condition = condition.is_a?(Condition) ? condition : Condition.new(condition)
           @request = request.is_a?(Request) ? request : Request.new(request)
           @polymorphs = []
           @order = []
           if (proc)
               @condition = Condition.new(&proc)
           end
       end
       
       # Sets the condition. If val is not a Condition, will attempt to convert it to one.
       def condition=(val)
           if (!val.is_a?(Condition))
               @condition = Condition.new(val)
           else
               @condition = val
           end
       end
       
       # Sets the request. If val is not a Request, will attempt to convert it to one.
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
       
       # Adds each element in the given list to the request.
       def select(*elements)
           elements.each do |element|
               @request.request(element.to_s)
           end
           return self
       end
       
       # Takes an argument or a block.
       # If given an argument, will use it as a Condition. If given a block, will use it on the Condition.
       def where(condition=nil, &proc)
           condition = Condition.new(&proc) unless (condition)
           @condition << condition
           return self
       end
       
       # Requests a polymorph.
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
       def only_polymorphs
           @request.only_polymorphs
       end
       
       def with_superclass
           @request.with_superclass
       end
       
       def first
           self.limit = 1
       end

       def only_one
           self.limit = 1
           @only_one = true
       end


       def only_one?
           @only_one
       end
       
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
       
       def polymorphs? # :nodoc:
           @polymorphs.length > 0
       end
       
       # Returns a deep copy.
       def clone
           cl = self.class.new(@condition.clone, @request.clone)
           cl.order = @order.clone
           cl.offset = @offset
           cl.limit = @limit
           cl.polymorphs = @polymorphs.clone
           return cl
       end
       
       
        
    end
    

    
end; end
