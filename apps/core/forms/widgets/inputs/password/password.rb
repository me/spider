module Spider; module Forms
    
    class Password < Input
        tag 'password'
        is_attr_accessor :size, :type => Fixnum, :default => 25

        def prepare
            super
            @modified = false
            if (params['pwd1'] && !params['pwd1'].empty? && params['pwd2'])
                if (params['pwd1'] != params['pwd2'])
                    add_error("Le due password non corrispondono")
                else
                    @value = params['pwd1']
                    @modified = true
                end
            end
        end
        
        def value=(val)
        end

    end
    
end; end