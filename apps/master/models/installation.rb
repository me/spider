module Spider; module Master
    
    class Installation < Spider::Model::Managed
        element :uuid, UUID
        element :name, String, :label => _('Name')
        choice :customer, Customer, :add_multiple_reverse => :installations
        element :apps, Text, :hidden => true
        element :ip_address, String
        element :hostname, String
        element :configuration, Text, :hidden => true
        element :last_check, DateTime, :hidden => true
        element :interval, Fixnum, :hidden => true
        
        def to_s
            str = self.name || self.uuid
            if self.customer
                str += " - #{self.customer}"
            end
        end
        
    end
    
end; end