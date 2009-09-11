require 'spiderfw/model/base_model'

module Spider; module Model
    
    # The main superclass of non-legacy models.
    # Extends the BaseModel providing an autoincrementing id and creation/modification timestamps.
    # Defines the following elements:
    #   element :id, Fixnum, :primary_key => true,:autoincrement => true, :read_only => true, :element_position => 0}
    #   element :obj_created, DateTime, :hidden => true
    #   element :obj_modified, DateTime, :hidden => true
    # 
    # Other modules may be mixed-in to add default functionality to managed models.
    
    class Managed < BaseModel
        element :id, Fixnum, {
            :primary_key => true, 
            :autoincrement => true, 
            :read_only => true, 
            :element_position => 0
        }
        element :obj_created, DateTime, :hidden => true
        element :obj_modified, DateTime, :hidden => true
        

        def assign_id(val) #:nodoc:
            @id = val
        end
        
        def self.managed?
            true
        end
        
        with_mapper do
            def before_save(obj, mode)
                obj.obj_created = DateTime.now if mode == :insert
                obj.obj_modified = DateTime.now if obj.modified?
                super
            end
        end
        
    end
            
end; end