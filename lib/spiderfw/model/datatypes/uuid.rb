require "uuid"

module Spider; module DataTypes

    # RFC 4122 UUID

    class UUID < String
        include DataType
        
        # format :short returns just the first part
        def format(type)
            if (type == :short)
                return self.to_s.split('-')[0]
            end
            return super
        end

    end
    
    
end; end