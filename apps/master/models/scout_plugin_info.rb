module Spider; module Master
    
    class ScoutPluginInfo < Spider::Model::Managed
        remove_element :id
        element :id, String
        element :name, String
        element :description, Text
        
    end
    
end; end