module Spider::CommandLine

    class ModelCommand < CmdParse::Command


        def initialize
            super( 'model', true, true )
            @short_desc = _("Manage models")
            @apps = []
            @force = false
            @no_fkc = true

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
                opt.on("--no-fk-constraints", _("Don't create foreign key constraints"), "-c"){ |c| @no_fkc = true }
                opt.on("--fk-constraints", _("Create foreign key constraints"), "-C" ){ |c| @no_fkc = false } 
            end
            
            sync_cmd.set_execution_block do |req_models|
                require 'spiderfw/init'
                require 'spiderfw/model/mappers/db_mapper'
                req_models || []
                unsafe_fields = {}
                req_models = Spider.apps.values if (req_models.empty?)
                req_models.each do |model_or_app|
                    models = []
                    mod = model_or_app.is_a?(Module) ? model_or_app : const_get_full(model_or_app)

                    if mod.is_a?(Module) && mod.include?(Spider::App)
                        mod.models.each do |m|
                            storage_instance = m.storage.respond_to?(:instance_name) ? m.storage.instance_name : nil
                            if @non_managed || m < Spider::Model::Managed #|| storage_instance == 'default'
                                models << m
                            else
                                unless m < Spider::Model::InlineModel || m.attributes[:sub_model]
                                    Spider.logger.warn("Skipping #{m} because it's non managed (use -m to override)")
                                end
                                next
                            end
                        end
                    elsif mod.subclass_of?(Spider::Model::BaseModel)
                        storage_instance = mod.storage.respond_to?(:instance_name) ? mod.storage.instance_name : nil
                        if @non_managed || mod < Spider::Model::Managed #|| storage_instance == 'default'
                            models << mod
                        else
                            Spider.logger.warn("Skipping #{mod} because it's non managed (use -m to override)")
                        end
                        
                    end
                    models.each do |model|
                        begin
                            Spider::Model.sync_schema(model, @force, 
                            :drop_fields => @drop, :update_sequences => @update_sequences, :no_foreign_key_constraints => @no_fkc)
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
            
            dump_cmd = CmdParse::Command.new( 'dump', false )
            dump_cmd.short_desc = _("Dump models")
            dump_cmd.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.on("--force", _("Overwrite existing files"), "-f"){ |f|
                    @force = true
                }
                opt.on("--path [PATH]", _("Specify dump path"), "-p"){ |p|
                    @dump_path = p
                }
            end
            dump_cmd.set_execution_block do |req_models|
                require 'spiderfw/init'
                req_models || []
                req_models.each do |model_or_app|
                    models = []
                    mod = model_or_app.is_a?(Module) ? model_or_app : const_get_full(model_or_app)
                    if (mod.is_a?(Module) && mod.include?(Spider::App))
                        mod.models.each do |m|
                            models << m
                        end
                    elsif (mod.subclass_of?(Spider::Model::BaseModel))
                        models << mod if @non_managed || mod < Spider::Model::Managed
                    end
                    Spider.logger.warn("Nothing to do") if models.empty?
                    models.each do |model|
                        dest = @dump_path || model.app.models_path
                        FileUtils.mkdir_p(dest)
                        file_name = "#{model.short_name}.rb"
                        path = "#{dest}/#{file_name}"
                        if (File.exist?(path) && !@force)
                            Spider.logger.warn("File #{path} exists, skipping #{model}")
                            next
                        end
                        code = model.to_code
                        File.open(path, "w") do |f|
                            f << code
                        end
                    end
                end
            end
            self.add_command(dump_cmd)


        end

    end

end
