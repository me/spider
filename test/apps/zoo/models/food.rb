module Zoo
    
    class Food < Spider::Model::Managed
        remove_element :id
        element :id, String, :primary_key => true
        element :name, String
        
    end
    
    
end