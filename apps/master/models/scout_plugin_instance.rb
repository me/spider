require 'json'
require 'apps/master/models/scout_plugin_trigger'
require 'apps/master/models/scout_average'

module Spider; module Master
    
    class ScoutPluginInstance < Spider::Model::Managed
        element :plugin_id, String
        element :name, String
        element :servant, Servant, :add_multiple_reverse => :scout_plugins
        element :settings_json, Text
        element :timeout, Fixnum, :default => 60
        element :poll_interval, Fixnum, :default => 0
        many :triggers, ScoutPluginTrigger, :add_reverse => :plugin_instance, :delete_cascade => true
        multiple_choice :admins, Master::Admin, :add_multiple_reverse => :plugin_instances do
            element :receive_notifications, Bool, :default => true
            element :manage, Bool, :default => true
        end
        many :averages, ScoutAverage, :add_reverse => :plugin_instance, :delete_cascade => true
        choice :status, {
            :ok => _('Ok'),
            :error => _('Error'),
            :alert => _('Alert')
        }, :default => :ok
        element :averages_computed_at, Date

        
        
        def plugin
            @plugin ||= ScoutPlugin.new(self.plugin_id)
        end

        def fields_array
            return [] unless self.fields
            self.fields.split(',').sort
        end
        
        def settings
            if self.settings_json
                begin
                    opts = JSON.parse(self.settings_json)
                rescue JSON::ParserError => exc
                end
            end
            opts ||= {}
            @plugin.options.each do |id, opt|
                opts[id] ||= opt["default"]
            end
            opts
        end
        
        def settings=(hash)
            @plugin.options.each do |id, opt|
                hash.delete(id) if hash[id] == opt["default"]
            end
            self.settings_json = hash.to_json
        end

        def metadata
            self.plugin ? self.plugin.metadata : {}
        end
        
        def report_admins
            admins = self.admins.reject{ |adm| !adm.receive_notifications }.map{ |adm| adm.admin }
        end

        def last_error
            last = ScoutError.where(:plugin_instance => self).order_by(:obj_created, :desc)
            last.limit = 1
            last[0]
        end
        
        def last_reported(key=nil)
            return last_report unless key
            last = last_field(key)
            return last ? last.value : nil
        end
        
        def last_report
            last = ScoutReport.where(:plugin_instance => self).order_by(:obj_created, :desc)
            last.limit = 1
            last[0]
        end
        
        def last_field(key)
            last = last_report
            return nil unless last
            last.field(key)
        end
        
        def last_keys
            fields = []
            last = self.last_reported
            if last
                fields = last.fields.map{ |f| f.name }.sort
            end
            fields
        end
        
        def to_s
            "#{self.name} - #{self.servant}"
        end
        
                
        def compute_averages
            today = Date.today - 1
            last = today - 7
            yesterday = today - 1
            
            fields = ScoutReportField.where{ |f| 
                (f.plugin_instance == self) & (f.report_date > last) & (f.report_date < today) 
            }
            week_values = {}
            day_values = {}
            p "TOTAL ROWS: #{fields.total_rows}"
#            t1 = Time.now
            Spider::Profiling.start
            fields[0]
 #           t2 = Time.now
 #           Spider.logger.debug("DONE IN #{(t2 - t1).to_i} seconds")
            Spider::Profiling.stop
            fields.each do |f|
                day_values[f.name] ||= []
                week_values[f.name] ||= []
                next unless f.value
                week_values[f.name] << f.value
                if f.report_date > yesterday
                    day_values[f.name] << f.value
                end
            end

            week_values.keys.each do |key|
                if week_values[key].length > 0
                    week_average = week_values[key].inject(0.0){ |sum, v| sum + v } / week_values[key].length
                end
                if day_values[key].length > 0
                    day_average = day_values[key].inject(0.0){ |sum, v| sum + v} / day_values[key].length
                end
                ScoutAverage.in_transaction do
                    ScoutAverage.where{ |a| 
                        (a.plugin_instance == self) & (a.field_name == key)
                    }.each{ |a| a.delete }
                    if week_average
                        ScoutAverage.create(
                            :plugin_instance => self,
                            :field_name => key,
                            :type => :week,
                            :mean => week_average,
                            :date => last
                        )
                    end
                    if day_average
                        ScoutAverage.create(
                            :plugin_instance => self,
                            :field_name => key,
                            :type => :day,
                            :mean => day_average,
                            :date => yesterday
                        )
                    end
                end
            end
            
            
            fields = ScoutReportField.where{ |f| 
                (f.plugin_instance == self) & (f.report_date < last) & (f.mean == nil)
            }.order_by(:name, :report_date)
            last_key = nil
            last_date = nil
            averages = []
            values = []
            seen = {}
            day_values = []
            fields.each do |f|
                if last_key && f.name != last_key
                    unless values.empty?
                        averages << hourly_averages(values, last_date)
                        commit_averages(last_key, averages, last)
                    end
                    last_date = nil
                    values = []
                end
                last_key = f.name
                date = f.report_date
                if last_date && last_date.hour != date.hour
                    averages << hourly_averages(values, last_date)
                end
                values << f.value
                if f.report_date.day == yesterday.day
                    day_values << f.value
                end
                last_date = date
            end
            unless values.empty?
                averages << hourly_averages(values, last_date)
                commit_averages(last_key, averages, last)
            end
            
            self.averages_computed_at = today
            self.save
        end
        
        def commit_averages(key, averages, last)
            ScoutReportField.in_transaction do
                c = Spider::Model::Condition.new{ |f| (f.name == key) & (f.report_date < last) & (f.mean == nil) }
                ScoutReportField.mapper.delete(c)
                averages.each do |av|
                    ScoutReportField.create(
                        :name => key,
                        :plugin_instance => self,
                        :report_date => av[0],
                        :cnt => av[1],
                        :mean => av[2],
                        :mode => av[3],
                        :stdev => av[4],
                        :high => av[5],
                        :low => av[6],
                        :value => av[2]
                    )
                end
            end
        end
        
        def hourly_averages(values, last_date)
            n = values.length
            sum = values.inject(0.0){ |acc, i| acc + i }
            mean = sum / values.length
            variance = values.inject(0.0){ |sum, v| sum + (v - mean)**2 } / (n - 1)
            stddev = Math.sqrt(variance)
            high = values.max
            low = values.min
            freq = values.inject(Hash.new(0)){ |h, i| h[i] += 1; h }
            mode = values.sort_by { |v| freq[v] }.last
            
            average_date = DateTime.civil(
                last_date.year, last_date.month, last_date.day, last_date.hour, 0, 0
            )
            [average_date, n, mean, mode, stddev, high, low]
        end
        
        with_mapper do
            
            def before_save(obj, mode)
                if mode == :insert
                    obj.servant.admins.each do |servant_adm|
                        obj.admins << ScoutPluginInstance::Admins.new(
                           :admin => servant_adm.admin,
                           :receive_notifications => servant_adm.receive_notifications,
                           :manage => servant_adm.manage_plugins
                        )
                    end
                end
                super
            end
            
            def after_save(obj, mode)
                if mode == :insert
                    obj.plugin.triggers.each do |tr|
                        trigger = ScoutPluginTrigger.from_plugin(tr)
                        trigger.plugin_instance = obj
                        trigger.save
                    end
                end
                if obj.servant
                    obj.servant.scout_plan_changed = DateTime.now
                    obj.servant.save
                end
                super
            end
            
        end
            
        
    end
    
end; end
