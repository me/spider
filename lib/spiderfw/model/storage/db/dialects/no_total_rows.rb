module Spider; module Model; module Storage; module Db; module Dialects
    
    module NoTotalRows
        
        def total_rows
            return nil unless @last_executed
            q = @last_query.clone
            unless (q[:offset] || q[:limit])
                return @last_result ? @last_result.length : nil
            end
            q.delete(:offset); q.delete(:limit); q[:order]= []
            q[:query_type] = :count
            return query(q)
        end
        
    end
    
end; end; end; end; end