module Spider; module AppServer
    
    class AppServerController < Spider::PageController
        
        layout 'app_server'
        
        __.html :template => 'app_list'
        __.json :call => :list_json
        def list
            @scene.apps = AppServer.apps
        end
        
        def list_json
            $out << AppServer.apps.to_json
        end
        
    end
    
    
end; end