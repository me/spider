require 'spider/model/base_model'

module Spider; module Model
    
    class Managed < BaseModel
        element :id, 'int', {:primary_key => true, :read_only => true}
        
        def id=(val)
            raise ModelException, "You can't assign a value to the 'id' element"
        end
        
        def assign_id(val)
            @id = val
        end
        
        def self.managed?
            true
        end
        
    end
            
end; end