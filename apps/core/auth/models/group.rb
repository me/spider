require 'spiderfw/model/mixins/tree'
require 'apps/core/auth/models/mixins/access_control'
require 'uuidtools'

module Spider; module Auth
    
    class Group < Spider::Model::BaseModel
        include Spider::Model::Tree
        tree :subgroups
        element :gid, String, :primary_key => true
        element :label, String, :required => true, :check => /[\w\d_]+/, :unique => true
        element :name, String
        
        with_mapper_subclasses do
            def assign_primary_keys(obj)
                obj.set(:gid, UUIDTools::UUID.random_create.to_s)
            end
        end
        
    end
    
end; end