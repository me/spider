require 'spiderfw/model/base_model'

module Spider; module Model
    
    class Managed < BaseModel
        element :id, Fixnum, {
            :primary_key => true, 
            :autoincrement => true, 
            :read_only => true, 
            :element_position => 0
        }
        element :obj_created, DateTime, :hidden => true
        element :obj_modified, DateTime, :hidden => true
        
        # def id=(val)
        #     raise ModelException, "You can't assign a value to the 'id' element"
        # end
        
        def assign_id(val)
            @id = val
        end
        
        def self.managed?
            true
        end
        
        with_mapper do
            def before_save(obj, mode)
                obj.obj_created = DateTime.now if mode == :insert
                obj.obj_modified = DateTime.now
                super
            end
        end
        
    end
            
end; end