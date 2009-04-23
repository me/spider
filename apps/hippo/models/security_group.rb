module Hippo
    
   class SecurityGroup < Spider::Model::BaseModel
       include HippoStruct

       element :name, String
#       element :parent, Hippo::SecurityGroup
       
       use_storage 'hippo'
       # binding({
       #     :table => '_SECURITY_GROUP',
       #     :elements => {
       #         "name" => {:field => "NAME"},
       #         "parent" => {:field => "ID_PARENT"}
       #     }
       # 
       # })

   end
   
end
