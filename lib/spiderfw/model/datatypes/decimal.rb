require "bigdecimal"

module Spider; module DataTypes

    # A wrapper around BigDecimal.
    # Takes the :scale attribute.

    class Decimal < BigDecimal
        include DataType

        #maps_back_to superclass
        
        take_attributes :scale
        
        def self.from_value(value)
            return nil if value.nil?
            super(value.to_s)
        end
        
        def prepare
            self.class.from_value(self.round(attributes[:scale] || 2))
        end
        
        def to_s(s=nil)
            s ||= "#{attributes[:scale]}F"
            super(s)
        end
        


    end
    
    
end; end