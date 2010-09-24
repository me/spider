require 'apps/master/models/scout_report_field'
require 'apps/master/models/scout_average'

module Spider; module Master
    
    class ScoutReport < Spider::Model::Managed
       element :created_at, DateTime
       element :plugin_instance, ScoutPluginInstance, :add_multiple_reverse => :reports
       many :fields, ScoutReportField, :add_reverse => :report
       many :averages, ScoutAverage, :add_reverse => :report
       
       
       
        
    end
    
end; end