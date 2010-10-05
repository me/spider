module Spider; module Master
    
    class ScoutAverage < Spider::Model::Managed        
        element :field_name, String
        choice :type, {
            :hour => 'hourly',
            :day => 'daily',
            :week => 'weekly',
            :month => 'monthly',
            :year => 'yearly'
        }
        element :date, Date
        element :mean, Decimal
        element :median, Decimal
        element :mode, Decimal
        element :stdev, Decimal
        element :high, Decimal
        element :low, Decimal
        element :cnt, Fixnum
        
    end
    
end; end