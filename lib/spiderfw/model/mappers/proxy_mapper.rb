require 'spiderfw/model/mappers/mapper'

module Spider; module Model; module Mappers

    # TODO: remove?
    class ProxyMapper #:nodoc:
        
        def initialize(model, proxied_model)
            @model = model
            @proxied_model = proxied_model
        end
        
        def find(query, query_set=nil)
            set = query_set || QuerySet.new(@model)
            @proxied_model.mapper.find(query, set)
        end
 
        def method_missing(method, *args)
            @proxied_model.mapper.send(method, *args)
        end
        
    end
    
    
end; end; end