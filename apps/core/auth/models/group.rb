require 'spiderfw/model/mixins/tree'
require 'apps/core/auth/models/mixins/access_control'
require 'uuid'

module Spider; module Auth
    
    class Group < Spider::Model::BaseModel
        include Spider::Model::Tree
        tree :subgroups
        element :gid, String, :primary_key => true
        element :label, String, :required => true, :check => /[\w\d_]+/, :unique => true
        element :name, String
        
        with_mapper do
            def assign_primary_keys(obj)
                obj.set(:gid, UUID.new.generate)
            end
        end
        
    end
    
end; end