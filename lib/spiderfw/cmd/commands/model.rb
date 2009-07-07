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
                dt = true if dt == '*'
                @drop_tables = dt
            }
            opt.on("--update-sequences", _("Update current sequences to max db value"), "-s"){ |s|
                @update_sequences = true
            }
            opt.on("--non-managed", _("Process also non managed models"), "-m"){ |m| @non_managed = true}
        end
        
        sync_cmd.set_execution_block do |req_models|
            require 'spiderfw'
            req_models || []
            unsafe_fields = {}
            req_models = Spider.apps.values if (req_models.empty?)
            req_models.each do |model_or_app|
                models = []
                mod = model_or_app.is_a?(Module) ? model_or_app : const_get_full(model_or_app)
                if (mod.is_a?(Module) && mod.include?(Spider::App))
                    mod.models.each do |m|
                        next unless @non_managed || m < Spider::Model::Managed
                        models << m
                    end
                elsif (mod.subclass_of?(Spider::Model::BaseModel))
                    models << mod if @non_managed || mod < Spider::Model::Managed
                end
                models.each do |model|
                    begin
                        Spider::Model.sync_schema(model, @force, 
                        :drop_fields => @drop, :update_sequences => @update_sequences)
                    rescue Spider::Model::Mappers::SchemaSyncUnsafeConversion => exc
                        unsafe_fields[model] = exc.fields
                    end 
                end
                if (@drop_tables)
                    begin
                        Spider::Model.sync_schema(mod, false, :no_sync => true, :drop_tables => @drop_tables)
                    rescue Spider::Model::Mappers::SchemaSyncUnsafeConversion => exc
                        puts _("The following tables are about to be dropped: \n%s") % exc.fields.join(', ')
                        puts _("Continue? yes/NO: ")
                        r = STDIN.gets.chomp.downcase
                        yes_chr = _("yes")[0].chr
                        no_chr = _("no")[0].chr
                        debugger
                        if (r == _("yes") || (yes_chr != no_chr && r == yes_chr)) 
                            Spider::Model.sync_schema(mod, true, :no_sync => true, :drop_tables => @drop_tables)
                        end
                    end
                        
                        
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