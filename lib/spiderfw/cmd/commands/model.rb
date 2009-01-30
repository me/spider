class ModelCommand < CmdParse::Command


    def initialize
        super( 'model', true, true )
        @short_desc = _("Manage models")
        @apps = []

        sync_cmd = CmdParse::Command.new( 'sync', false )
        sync_cmd.short_desc = _("Sync models")
        
        sync_cmd.set_execution_block do |req_models|
            models = []
            req_models || []
            req_models.each do |model|
                mod = const_get_full(model)
                if (mod.is_a?(Module) && mod.include?(Spider::App))
                    mod.models.each { |m| models << m }
                elsif (mod.is_a?(Spider::Model::BaseModel))
                    models << mod
                end
            end
            models.each do |m|
                m.mapper.sync_schema if m.mapper.respond_to?(:sync_schema)
            end
        end
        self.add_command(sync_cmd)


    end

end