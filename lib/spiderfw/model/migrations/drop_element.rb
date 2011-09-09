module Spider; module Migrations

    class DropElement < IrreversibleMigration

        def initialize(model, element, options={})
            @model = model
            @element = element
            @options = options
        end

        def run
            field = @options[:field_name] || @model.mapper.schema.field(@element)
            field ||= @model.mapper.storage.column_name(@element)
            desc = @model.mapper.storage.describe_table(@model.mapper.schema.table)
            if desc[:columns][field]
                @model.mapper.storage.drop_field(@model.mapper.schema.table, field)
            end
        end

    end

end; end