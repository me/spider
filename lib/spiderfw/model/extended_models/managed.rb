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
        element :obj_created, DateTime, :label => _('Created'), :hidden => true
        element :obj_modified, DateTime, :label => _('Modified'), :hidden => true
        

        def assign_id(val) #:nodoc:
            @id = val
        end
        
        def self.managed?
            true
        end
        
        def _set_dates(bool=nil)
            @_set_dates = true if @_set_dates == nil
            @_set_dates = bool if bool != nil
            @_set_dates
        end
        
        
        with_mapper do
            def before_save(obj, mode)
                if obj._set_dates
                    obj.obj_created = DateTime.now if mode == :insert
                    obj.obj_modified = DateTime.now if obj.modified?
                end
                super
            end
        end
        
    end
            
end; end