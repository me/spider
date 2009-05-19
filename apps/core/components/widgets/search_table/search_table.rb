module Spider; module Components
    
    class SearchTable < Spider::Components::Table
        tag 'search-table'
        
        def prepare
            super
            params['q'] = nil if params['clear']
            @scene.query = params['q']
        end
 
        def prepare_queryset(qs)
            qs = super
            if (params['q'])
                qs.condition = qs.condition.and(@model.free_query_condition(params['q']))
            end
            return qs
        end
        
    end
    
end; end