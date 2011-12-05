module Spider; module Migrations

    class RenameElement < Migration

        def initialize(model, element, new_element, options={})
            @model = model
            @element = element
            @new_element = new_element
            @options = {}
        end

        def run
            field = @options[:field_name]
            schema_field = nil
            new_schema_field = nil
            unless field
                schema_field = @model.mapper.schema.field(@element)
                field = schema_field.name if schema_field
            end
            field ||= @model.mapper.storage.column_name(@element)
            new_field = @options[:new_field_name]
            unless new_field
                new_schema_field = @model.mapper.schema.field(@new_element)
                new_field = new_schema_field.name if new_schema_field
            end
            new_field ||= @model.mapper.storage.column_name(@new_element)
            f = new_schema_field || schema_field
            raise "Neither #{@element} nor #{@new_element} were found in schema" unless f

            desc = @model.mapper.storage.describe_table(@model.mapper.schema.table)
            if desc[:columns][field] && !desc[:columns][new_field]
                @model.mapper.storage.change_field(@model.mapper.schema.table, field, new_field, f.type, f.attributes)
            end
        end

        def undo
            self.class.new(@model, @new_element, @element).run
        end

    end

end; end
