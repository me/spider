require 'spiderfw/model/mixins/tree'
require 'apps/core/auth/models/mixins/access_control'
require 'uuidtools'

module Spider; module Auth
    
    class Group < Spider::Model::BaseModel
        include Spider::Model::Tree
        tree :subgroups
        element :gid, Spider::DataTypes::UUID, :primary_key => true
        element :label, String, :required => true, :check => /[\w\d_]+/, :unique => true, :label => _('Label')
        element :name, String, :label => _('Name')
        
        
    end
    
end; end