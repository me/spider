require "bigdecimal"

module Spider; module DataTypes

    class Decimal < DataType
        maps_to BigDecimal
        take_attributes :scale
        
        def set(value)
            @val = BigDecimal.new(value.to_s).round(attributes[:scale] || 2)
        end

    end
    
    
end; end