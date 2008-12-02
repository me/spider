require 'spiderfw/model/condition'
require 'spiderfw/model/request'

module Spider; module Model
    
    class Query
        attr_accessor :order, :offset, :limit
        attr_reader :condition, :request, :polymorphs
       
       def initialize(condition = nil, request=nil, &proc)
           @condition = Condition.new(condition)
           @request = Request.new(request)
           @polymorphs = []
           @order = []
           if (proc)
               defined_methods = define_helper_methods
               instance_eval(&proc) 
               undefine_helper_methods if (defined_methods)
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
       
       def where(condition)
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
       
       private
       def define_helper_methods
           return false if (String.method_defined? :spider_query_methods_set)
           String.class_eval do
               def spider_query_methods_set
               end
               alias :spider_query_old_pipe :| if method_defined? :|
               def |(other)
                   cond = Spider::Model::Condition.new
                   cond.conjunction = 'or'
                   cond << self
                   cond << other
                   return cond
               end
               def &(other)
                   cond = Spider::Model::Condition.new
                   cond.conjunction = 'and'
                   cond << self
                   cond << other
                   return cond
               end
           end
           return true
       end
       
       private
       def undefine_helper_methods
           return false unless (String.method_defined? :spider_query_methods_set)
           String.class_eval do
               if method_defined? :spider_query_old_pipe
                   alias :| :spider_query_old_pipe
                   undef_method :spider_query_old_pipe
               else
                   undef_method :|
               end
               if method_defined? :spider_query_old_amper
                   alias :& :spider_query_old_amper
                   undef_method :spider_query_old_amper
               else
                   undef_method :&
               end
               undef_method :spider_query_methods_set
           end
           return true
       end
       
        
    end
    
end; end