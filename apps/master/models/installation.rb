module Spider; module Master
    
    class Installation < Spider::Model::Managed
        element :name, String
        element :apps, Text
        element :configuration, Text
        
    end
    
end; end