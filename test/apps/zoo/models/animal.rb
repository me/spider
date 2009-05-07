require 'apps/zoo/models/family'
require 'apps/zoo/models/food'

module Zoo
    
    class Animal < Spider::Model::Managed
        element :id, String, :primary_key => true
        element :name, String
        element :comment, Text
        choice :family, Family
        multiple_choice :foods, Food
        multiple_choice :friends, Animal
        
    end
    
    
end