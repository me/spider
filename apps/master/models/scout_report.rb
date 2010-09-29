require 'apps/master/models/scout_report_field'
require 'apps/master/models/scout_average'

module Spider; module Master
    
    class ScoutReport < Spider::Model::Managed
       element :created_at, DateTime
       element :plugin_instance, ScoutPluginInstance, :add_multiple_reverse => {:name => :reports, :delete_cascade => true}
       many :fields, ScoutReportField, :add_reverse => {:name => :report, :integrate => true}, :delete_cascade => true
       many :averages, ScoutAverage, :add_reverse => :report, :delete_cascade => true
       
       def field(key)
           return @fields_hash[key] if @fields_hash
           @fields_hash = {}
           self.fields.each do |field|
               @fields_hash[field.name] = field
           end
           @fields_hash[key]
       end
       
       def value(key)
           f = field(key)
           return nil unless f
           f.value
       end
       
       
        
    end
    
end; end
