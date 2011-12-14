module Spider; module Migrations
    
    class Replace < Migration
        
        def initialize(model, element, values)
            @models = model
            @models = [@models] unless @models.is_a?(Enumerable)
            @element = element
            @values = values
        end
        
        def run
            @models.each do |model|
                field = model.mapper.schema.field(model.get_element(@element).name)
                table = model.mapper.schema.table
                raise "Table #{table} does not have a field #{field}" unless field
                @values.each do |from, to|
                    save = {
                        :table => table, 
                        :values => {field => to},
                        :condition => {:values => [[field, '=', from]]}
                    }
                    sql, bind_vars = model.storage.sql_update(save)
                    model.storage.execute(sql, *bind_vars)                
                end
            end
        end
        
        def undo
            @models.each do |model|
                Replace.new(model, @element, @values.invert).run
            end
        end
        
    end
    
end; end