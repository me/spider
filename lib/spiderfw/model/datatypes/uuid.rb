require "uuid"

module Spider; module DataTypes

    class UUID < String
        include DataType
        
        def format(type)
            if (type == :short)
                return self.to_s.split('-')[0]
            end
            return super
        end

    end
    
    
end; end