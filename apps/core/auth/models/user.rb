require 'apps/core/auth/models/group'
require 'uuid'

module Spider; module Auth
    
    class User < Spider::Model::BaseModel
        element :uid, String, :primary_key => true
        many :groups, Spider::Auth::Group, :add_multiple_reverse => :users
        
        with_mapper do
            def assign_primary_keys(obj)
                obj.set(:uid, UUID.new.generate)
            end
        end
        
    end
    
end; end