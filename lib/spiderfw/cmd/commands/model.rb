class ModelCommand < CmdParse::Command


    def initialize
        super( 'model', true, true )
        @short_desc = _("Manage models")
        @apps = []
        @force = false

        sync_cmd = CmdParse::Command.new( 'sync', false )
        sync_cmd.short_desc = _("Sync models")
        sync_cmd.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--force", _("Force syncing"), "-f"){ |f|
                @force = true
            }
            opt.on("--drop-columns", _("Drop unused columns"), "-d"){ |d| @drop = true}
            opt.on("--drop-tables [PREFIX]", _("Drop unused tables")){ |dt| 
                @drop_tables = dt
            }
        end
        
        sync_cmd.set_execution_block do |req_models|
            require 'spiderfw'
            req_models || []
            unsafe_fields = {}
            req_models.each do |model|
                begin
                    Spider::Model.sync_schema(model, @force, :drop_fields => @drop, :drop_tables => @drop_tables)
                rescue Spider::Model::Mappers::SchemaSyncUnsafeConversion => exc
                    unsafe_fields[model] = exc.fields
                end 
            end
            unless unsafe_fields.empty?
                puts _("Unable to modify the following fields:")
                puts unsafe_fields.inspect
                puts _("(use -f to force)")
            end
        end
        self.add_command(sync_cmd)


    end

end