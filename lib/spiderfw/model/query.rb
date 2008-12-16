require 'spiderfw/model/condition'
require 'spiderfw/model/request'

module Spider; module Model
    
    class Query
        attr_accessor :order, :offset, :limit
        attr_reader :condition, :request, :polymorphs
       
       def initialize(condition = nil, request=nil, &proc)
           @condition = condition.is_a?(Condition) ? condition : Condition.new(condition)
           @request = request.is_a?(Request) ? request : Request.new(request)
           @polymorphs = []
           @order = []
           if (proc)
               @condition = Condition.new(&proc)
           end
       end
       
       def condition=(val)
           if (!val.is_a?(Condition))
               @condition = Condition.new(val)
           else
               @condition = val
           end
       end
       
       def request=(val)
           if (!val.is_a?(Request))
               @request = Request.new(val)
           else
               @request = val
           end
       end
       
       def order_by(*labels)
           labels.each do |l|
               parts = l.split(' ')
               @order << [parts[0], parts[1]]
           end
       end
       
       def select(*elements)
           elements.each do |element|
               @request.request(element.to_s)
           end
           return self
       end
       
       def where(condition=nil, &proc)
           condition = Condition.new(&proc) unless (condition)
           if (condition.class == String)
               @condition << condition
           else
               @condition = condition
           end
           return self
       end
       
       def with_polymorph(type, query=nil)
           query = self.class.new(query) unless query.is_a?(self.class)
           @polymorphs << type
           @request.with_polymorphs(type, query.request)
           return self
       end
       
       ##############################
       # information methods        #
       ##############################
       
       def polymorphs?
           @polymorphs.length > 0
       end
       
       
        
    end
    

    
end; end