require "bigdecimal"

module Spider; module DataTypes

    # A wrapper around BigDecimal.
    # Takes the :scale attribute.

    class Decimal < BigDecimal
        include DataType

        maps_back_to superclass
        
        take_attributes :scale
        
        def set(value)
            @val = BigDecimal.new(value.to_s).round(attributes[:scale] || 2)
        end

    end
    
    
end; end