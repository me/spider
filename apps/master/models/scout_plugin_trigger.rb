require 'mailfactory'

module Spider; module Master
    
    class ScoutPluginTrigger < Spider::Model::Managed
        element :data, String
        choice :trigger_type, {
            :peak => _('Peak trigger'),
            :plateau => _('Plateau trigger'),
            :trend => _('Trend trigger')
        }, :default => :peak
        element :min_value, Decimal
        element :max_value, Decimal
        choice :direction, {
            :up => _('Up'),
            :down => _('Down'),
            :either => _('Either')
        }, :default => :up
        element :percentage_change, Decimal
        element :duration, Fixnum
        choice :window_reference, {
            :last_day => _("yesterday's average"),
            :last_week => _('previous 7-day average'),
            :preceding_window => _('preceding window')
        }, :default => :last_day
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
            precision ||= 2
            precision = precision.to_i
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
            md = self.metadata || {}
            data_name = md["label"] || self.data
            case self.trigger_type.id.to_sym
            when :peak
                values = {
                    :data_name => data_name,
                    :max_value => format_value(self.max_value, md["units"], md["precision"])
                }
            when :trend
                values = {
                    :data_name => data_name,
                    :direction => _(self.direction.to_s),
                    :percentage_change => "#{self.percentage_change.lformat(1)}%",
                    :duration => _("%d minutes") % self.duration,
                    :window => _(self.window_reference.to_s),
                    :min_value => format_value(self.min_value, md["units"], md["precision"])
                    
                }
            when :plateau
                values = {
                    :data_name => data_name,
                    :duration => _("%d minutes") % self.duration,
                    :max_value => format_value(self.max_value, md["units"], md["precision"])
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
        
        def check(series=nil)
            series = [series] if series && !series.is_a?(Enumerable)
            if self.data
                if series
                    return unless series.include?(self.data)
                else
                    series = [self.data]
                end
            else
                series ||= self.plugin_instance.last_keys
            end
            series.each do |s|
                last_field = self.plugin_instance.last_field(s)
                next unless last_field
                if self.trigger_type.id == :peak
                    if last_field.value > self.max_value
                        trigger_alert(s, {:value => last_field.value, :time => last_field.report_date})
                    end
                elsif self.trigger_type.id == :trend
                    if self.min_value && self.min_value != 0
                        next unless last_field.value > self.min_value
                    end
                    check_val = case self.window_reference.id
                    when :last_day
                        self.plugin_instance.average(s, :day)
                    when :last_week
                        self.plugin_instance.average(s, :week)
                    when :preceding_window
                        f = ScoutReportField.where{ |f| 
                            (f.plugin_instance == self.plugin_instance) & (f.name == s)
                        }.order_by(:report_date, :desc).limit(2)[1]
                        f ? f.value : nil
                    end
                    next unless check_val
                    if self.duration && self.duration > 0
                        check_from = Time.now - self.duration
                        values = ScoutReportField.where{ |f| 
                            (f.plugin_instance == self.plugin_instance) & (f.name == s) & (f.report_date > check_from)
                        }.map{ |f| f.value }
                    else
                        values = [last_field.value]
                    end
                    next unless values.length > 0
                    average = values.inject(0.0){ |sum, v| sum + v } / values.length
                    perc = (check_val*self.percentage_change)/100
                    do_trigger = false
                    if self.direction.id == :up || self.direction.id == :either
                        do_trigger = :up if average > (check_val + perc)
                    elsif self.direction.id == :down || self.direction.id == :either
                        do_trigger = :down if average < (check_val - perc)
                    end
                    if do_trigger
                        trigger_alert(s, {
                            :current_value => last_field.value,
                            :average => average,
                            :check_value => check_val,
                            :direction => do_trigger
                        })
                    end
                elsif self.trigger_type.id == :plateau
                    max = self.max_value
                    check_from = Time.now - self.duration
                    
                    last_good = ScoutReportField.where{ |f| 
                        (f.plugin_instance == self.plugin_instance) & (f.name == s) & (value < max)
                    }.order_by(:report_date, :desc).limit(1)[0]
                    
                    if !last_good || last_good.report_date < check_from
                        first_bad = ScoutReportField.where{ |f| 
                            (f.plugin_instance == self.plugin_instance) & (f.name == s) & (value >= max)
                        }.order_by(:report_date, :asc).limit(1)
                        first_bad.condition.set(:report_date, '>', last_good.report_date) if last_good
                        first_bad = first_bad[0]
                        if first_bad && first_bad.report_date <= check_from
                            trigger_alert(s, {
                                :first_value => first_bad.value,
                                :first_time => first_bad.report_date,
                                :last_value => last_field.value,
                                :last_time => last_field.report_date
                            })
                        end
                    end
                end
            end
        end
        
        def trigger_alert(series=nil, params={})
            if series.is_a?(Hash)
                params = series
                series = nil
            end
            series ||= self.data
            md = self.plugin_instance.plugin.metadata[series] || {}
            data_name = md["label"] || series
            vals = {}
            if self.trigger_type.id == :peak
                max_value = format_value(self.max_value, md["units"], md["precision"])
                value = format_value(params[:value], md["units"], md["precision"])
                time = params[:time].to_local_time.lformat
                msg = _("%s exceeded %s, increasing to %s at %s") % [data_name, max_value, value, time]
            elsif self.trigger_type.id == :trend
                current_value = format_value(params[:current_value], md["units"], md["precision"])
                check_value = format_value(params[:check_value], md["units"], md["precision"])
                direction = _(self.direction.to_s)
                percentage = "#{self.percentage_change.lformat(1)}%"
                duration = _("%d minutes") % self.duration
                window = _(self.window_reference.to_s)
                msg = _("%s went %s more than %s over the preceding %s minutes with respect to %s, and is now %s") % [
                    data_name, direction, percentage, duration, window, current_value
                ]
            elsif self.trigger_type.id == :plateau
                max_value = format_value(self.max_value, md["units"], md["precision"])
                first_value = format_value(params[:first_value], md["units"], md["precision"])
                first_time = params[:first_time].to_local_time.lformat
                last_value = format_value(params[:last_value], md["units"], md["precision"])
                last_time = params[:last_time].to_local_time.lformat
                msg = _("%s exceeded %s, increasing to %s at %s, and is still continuing at %s as of %s") % [
                    data_name, max_value, first_value, first_time, last_value, last_time
                ]
            end
            mail = MailFactory.new
            path_txt = MasterController.find_resource_path(:email, template+'.txt', nil, MasterController)
            path_html = MasterController.find_resource_path(:email, template+'.html', nil, MasterController)
            
            # ERB data
            server_id = self.plugin_instance.server.id
            server_name = self.plugin_instance.server.name
            plugin_id = self.plugin_instance.id
            plugin_name = self.plugin_instance.name
            message = msg
            
            text = ERB.new(IO.read(path_txt)).result if path_txt && File.exist?(path_txt)
            html = ERB.new(IO.read(path_html)).result if path_html && File.exist?(path_html)

            mail.text = text if text
            mail.html = html if html
            ScoutAlert.create(
                :plugin_instance => self.plugin_instance,
                :data_series => series,
                :subject => msg,
                :body => mail.body
            )
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
