module Spider; module Master
    
    class Customer < Spider::Model::Managed
        element :name, String
        element :uuid, UUID
        element :public_key, Text
        element :private_key, Text
        multiple_choice :admins, Master::Admin, :add_multiple_reverse => {:name => :customers, :association => :multiple_choice} do
            element :receive_notifications, Bool, :default => true
            element :manage_plugins, Bool, :default => true
        end
        
        with_mapper do
            
            def before_save(obj, mode)
                if mode == :insert
                    global = Admin.where(:global => true)
                    global.each do |adm|
                        obj.admins << adm
                    end
                end
                super
            end
            
        end
        
    end
    
end; end
