module Zoo
    
    class Food < Spider::Model::Managed
        element :id, String, :primary_key => true
        element :name, String
        
    end
    
    
end