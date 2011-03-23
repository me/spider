require 'delegate'

module Spider; module DataTypes
    
    class PK < Delegator
        include DataType
        mapper_dependant
        
        def initialize(obj)
            @delegate_sd_obj = obj
        end
        
        def __getobj__
            @delegate_sd_obj
        end
        alias :obj :__getobj__

        def __setobj__(obj)
            @delegate_sd_obj = obj
        end
        
        def self.force_wrap?
            false
        end

        
    end
    
end; end