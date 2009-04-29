require 'apps/hippo/models/security_group'

module Hippo
    
   class SecurityUser < Spider::Model::BaseModel
       include HippoStruct

       element :login, String, :required => true
       element :password, Spider::DataTypes::Password
       element :groups, Hippo::SecurityGroup, :multiple => true, :label => "Gruppi"
       
       use_storage 'hippo'
       binding({
           :table => '_SECURITY_USER',
           :elements => {
               "login" => {:field => "LOGIN"},
               "password" => {:field => "PASSWORD"},
               "groups" => {
                  :type=>"mmbind", 
                  :local_id=>"ID__SECURITY_USER",
                  :remote_id=>"ID__SECURITY_GROUP", 
                  :table=>"_SECURITY_GROUP_REF__SECURITY_USER"
              } 
           }
       })

   end
   
end