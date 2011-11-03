module Spider; module Migrations

    class DropTable < IrreversibleMigration

        def initialize(model, options={})
            @model = model
            @options = options
        end

        def run
            table = @options[:table_name]
            if !table
                table = @model.mapper.schema.table.name
            end
            @model.mapper.storage.drop_table(table)
        end

    end

end; end
