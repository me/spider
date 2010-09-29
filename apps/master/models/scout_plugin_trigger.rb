module Spider; module Master
    
    class ScoutPluginTrigger < Spider::Model::Managed
        element :data, String
        choice :trigger_type, {
            :peak => _('Peak trigger'),
            :plateau => _('Plateau trigger'),
            :trend => _('Trend trigger')
        }
        element :min_value, Decimal
        element :max_value, Decimal
        choice :direction, {
            :up => _('Up'),
            :down => _('Down'),
            :either => _('Either')
        }
        element :percentage_change, Decimal
        element :duration, Fixnum
        choice :window_reference, {
            :last_day => _("yesterday's average"),
            :last_week => _('previous 7-day average'),
            :preceding_window => _('preceding window')
        }
        choice :status, {
            :normal => _('normal'),
            :fired => _('fired')
        }, :default => :normal
        multiple_choice :report_to, Master::Admin, :add_multiple_reverse => :triggers do
            element :receive_emails, Bool, :default => true
            element :receive_sms, Bool, :default => true
        end
        
        
        
        def self.from_plugin(h)
            obj = self.new
            obj.data = h["dname"]
            obj.trigger_type = h["type"]
            obj.max_value = h["max_value"]
            obj.min_value = h["min_value"]
            obj.direction = h["direction"].downcase if h["direction"]
            obj.percentage_change = h["percentage_change"]
            obj.duration = h["duration"]
            obj.window_reference = h["window_reference"].downcase if h["window_reference"]
            obj
        end
        
        def metadata
            @metadata ||= self.plugin_instance.plugin.metadata[self.data]
        end
        
        def label
            return nil unless self.data && self.plugin_instance
            self.metadata['label']
        end
        
        def format_value(val, units, precision)
            str = "#{val.lformat(precision)}"
            str += " " unless units == "%"
            str += units if units
        end
        
        def report_admins
            no_admins = self.dont_report_to.map{ |adm| adm.id }
            admins = self.plugin_instance.report_admins.reject{ |adm| no_admins.include?(adm.id) }
        end
        
        def to_s
            "#{self.label} for #{self.plugin_instance}"
        end
        
        def description_html
            return nil unless self.trigger_type
            str = ""
            values = {}
            md = self.metadata
            return "" unless md
            data_name = md["label"]
            case self.trigger_type.id.to_sym
            when :peak
                values = {
                    :data_name => data_name,
                    :max_value => format_value(self.max_value, md["units"], md["precision"].to_i)
                }
            when :trend
                values = {
                    :data_name => data_name,
                    :direction => _(self.direction.to_s),
                    :percentage_change => "#{self.percentage_change.lformat(1)}%",
                    :duration => _("%d minutes") % self.duration,
                    :window => _(self.window_reference.to_s),
                    :min_value => format_value(self.min_value, md["units"], md["precision"].to_i)
                    
                }
            when :plateau
                values = {
                    :data_name => data_name,
                    :duration => _("%d minutes") % self.duration,
                    :max_value => format_value(self.min_value, md["units"], md["precision"].to_i)
                }
            end
            vals = values
            vals.each do |k, v|
                values[k] = '<span class="tr-val">'+v.to_s+'</span>'
            end
            case self.trigger_type.id.to_sym
            when :peak
                _("Alert me when %s exceeds %s") % [values[:data_name], values[:max_value]]
            when :trend
                _("Alert me when %s goes %s more than %s over the preceding %s (relative to %s), 
                as long as the value is at least %s") % [
                    values[:data_name], values[:direction], values[:percentage_change], values[:duration],
                    values[:window], values[:min_value]
                ]
            when :plateau
                _("Alert me when %s stays above %s for %s or more") % [
                    values[:data_name], values[:max_value], values[:duration]
                ]
            end
        end
        
        with_mapper do
            def before_save(obj, mode)
                if mode == :insert
                    obj.plugin_instance.admins.each do |instance_adm|
                        obj.report_to << ScoutPluginTrigger::ReportTo.new(
                           :admin => instance_adm.admin
                        )
                    end
                end
                super
            end
        end
        
    end
    
    
end; end
