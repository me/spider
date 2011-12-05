module Spider; module Migrations

    class DropElement < IrreversibleMigration

        def initialize(model, element, options={})
            @model = model
            @element = element
            @options = options
        end

        def run
            field = @options[:field_name]
            if !field
                schema_field = @model.mapper.schema.field(@element)
                field = schema_field.name if schema_field
            end
            field ||= @model.mapper.storage.column_name(@element)
            desc = @model.mapper.storage.describe_table(@model.mapper.schema.table)
            if desc[:columns][field]
                @model.mapper.storage.drop_field(@model.mapper.schema.table, field)
            end
        end

    end

end; end
