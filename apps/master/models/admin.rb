module Spider; module Master
    
    class Admin < Spider::Auth::LoginUser
        element :name, String
        element :email, String
        element :cell, String
        element :global, Bool, :default => false
        
        def can_manage_customer?(customer)
            customer = customer.id if customer.is_a?(Spider::Model::BaseModel)
            self.customers.map{ |c| c.customer.id }.include?(customer)
        end
        
        def can_manage_customers?
            self.global?
        end
        
        with_mapper do
           
           def before_save(obj, mode)
               if obj.global? && ( mode == :insert || obj.element_modified?(:global) )
                   curr = obj.customers.map{ |c| c.id }
                   missing = Customer.where{ |c| c.id .not curr }
                   missing.each do |c|
                       obj.customers << c
                   end
               end
               super
           end
            
        end
        
    end
    
end; end