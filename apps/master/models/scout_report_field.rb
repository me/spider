module Spider; module Master

    class ScoutReportField < Spider::Model::Managed
        element :name, String, :index => true
        element :value, Decimal
        element :report_date, DateTime, :default => lambda{ |obj| obj.report.created_at }
        element :plugin_instance, ScoutPluginInstance, :default => lambda{ |obj| obj.report.plugin_instance }
        element :mean, Decimal
        element :median, Decimal
        element :mode, Decimal
        element :stdev, Decimal
        element :high, Decimal
        element :low, Decimal
        element :cnt, Fixnum
        

    end

end; end