module Spider; module Master

    class ScoutReportField < Spider::Model::Managed
        element :name, String
        element :value, Decimal


    end

end; end