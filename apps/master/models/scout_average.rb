module Spider; module Master
    
    class ScoutAverage < Spider::Model::Managed
        choice :type, {
            :hour => 'hourly',
            :day => 'daily',
            :week => 'weekly',
            :month => 'monthly',
            :year => 'yearly'
        }
        element :field, String
        element :mean, Decimal
        element :median, Decimal
        element :mode, Decimal
        element :high, Decimal
        element :low, Decimal
        
    end
    
end; end