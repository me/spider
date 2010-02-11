module Zoo
    
    class Family < Spider::Model::Managed
        remove_element :id
        element :id, String, :primary_key => true
        element :name, String
        
    end
    
    
end