require 'spiderfw/model/condition'
require 'spiderfw/model/request'

module Spider; module Model
    
    class Query
        attr_accessor :order, :offset, :limit
        attr_reader :condition, :request, :polymorphs
        
        def self.where(*params)
            return self.class.new.condition.where(*params)
        end
       
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
               end
               @order << [parts[0], parts[1]]
           end
           return self
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
       
       def clone
           # FIXME: not sure cloning is ok on those two
           return self.class.new(@condition.clone, @request.clone)
       end
       
       
        
    end
    

    
end; end

require 'spiderfw/model/query_funcs'