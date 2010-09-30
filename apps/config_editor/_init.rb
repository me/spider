module Spider
    
    module ConfigEditor
        include Spider::App
        @controller = :ConfigEditorController
    end
    
end

Spider::Template.register_namespace('config_editor', Spider::ConfigEditor)


require 'apps/config_editor/controllers/config_editor_controller'
require 'apps/config_editor/widgets/edit/edit'