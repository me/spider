module Zoo
    
    class Family < Spider::Model::Managed
        element :id, String, :primary_key => true
        element :name, String
        
    end
    
    
end