class ModelCommand < CmdParse::Command


    def initialize
        super( 'model', true, true )
        @short_desc = _("Manage models")
        @apps = []

        sync_cmd = CmdParse::Command.new( 'sync', false )
        sync_cmd.short_desc = _("Sync models")
        
        sync_cmd.set_execution_block do |req_models|
            req_models || []
            req_models.each do |model|
                Spider::Model.sync_schema(model)
            end
        end
        self.add_command(sync_cmd)


    end

end