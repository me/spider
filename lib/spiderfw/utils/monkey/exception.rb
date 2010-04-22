require 'uuidtools'

module UUIDException
    
    def uuid=(val)
        @uuid = val
    end
    
    def uuid
        @uuid
    end
    
end

module UUIDExceptionMessage
    def message
        "#{@uuid} - #{super}"
    end
end

class Exception
    include UUIDException
end