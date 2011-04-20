module Spider; module Test
    
    class MapperStub < Spider::Model::Mapper
        
        def fetch(query)
            Spider::Model::QuerySet.static(@model)
        end
        
        def have_references?(element)
            false
        end
        
        def do_insert(obj)
        end
        
    end
    
end; end