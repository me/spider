module Spider; module ConfigEditor
    
    class Edit < Spider::Widget
        tag 'edit'
        
        is_attribute :name, :type => String
        is_attribute :option
        
        
        
    end
    
end; end