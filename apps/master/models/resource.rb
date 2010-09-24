module Spider; module Master
    
    class Resource < Spider::Model::Managed
        element :name, String
        element :resource_type, String
        element :description, Text
        element :attributes, Text
        
    end
    
end; end