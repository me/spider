require 'json'
require 'apps/master/models/scout_plugin_trigger'

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
        choice :status, {
            :ok => _('Ok'),
            :error => _('Error'),
            :alert => _('Alert')
        }, :default => :ok
        
        
        def plugin
            @plugin ||= ScoutPlugin.new(self.plugin_id)
        end
        
        def settings
            if self.settings_json
                begin
                    opts = JSON.parse(self.settings_json)
                rescue JSON::ParserError
                end
            end
            opts ||= {}
            @plugin.options.each do |id, opt|
                opts[id] = opt["default"] if opt["default"]
            end
            opts
        end
        
        def settings=(hash)
            @plugin.options.each do |id, opt|
                hash.delete(id) if hash[id] == opt["default"]
            end
            self.settings_json = hash.to_json
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
            last = ScoutReport.where(:plugin_instance => self).order_by(:obj_created, :desc)
            last.limit = 1
            return last[0].value(key) if key && last[0]
            return last[0]
        end
        
        def to_s
            "#{self.name} - #{self.servant}"
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
                super
            end
            
        end
            
        
    end
    
end; end
