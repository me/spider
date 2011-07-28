require 'apps/master/models/resource'
require 'apps/master/models/command'

module Spider; module Master
    
    class Server < Spider::Model::Managed
        element :uuid, UUID
        element :name, String
        element :last_check, DateTime, :read_only => true
        element :system_status, Text, :read_only => true
        element :scout_poll_interval, Fixnum, :default => 5
        # element :url, String
        many :commands, Master::Command, :add_reverse => :server
        element_query :pending_commands, :commands, :condition => Spider::Model::Condition.new{ |c| c.status == 'pending' }
        many :resources, Master::Resource, :delete_cascade => true
        choice :customer, Master::Customer, :add_multiple_reverse => :servers
        element :scout_plan_changed, DateTime, :hidden => true
        multiple_choice :admins, Master::Admin, :add_multiple_reverse => :server do
            element :receive_notifications, Bool, :default => true
            element :manage_plugins, Bool, :default => true
        end
        
        
        def resources_by_type
            r = {}
            self.resources.each do |res|
                r[res.resource_type] ||= {}
                r[res.resource_type][res.name] = res
            end
            r
        end
        
        def command(name, arguments={})
            if self.url
                # send_command(name, arguments)
            else
                c = Command.new(:name => name, :arguments => arguments.to_json, :server => self)
                c.save
            end
        end
        
        def to_s
            str = self.name
            str += " - #{self.customer}" if self.customer
            str
        end
        
        def scout_plan
            plan = {}
            plan["plugins"] = []
            self.scout_plugins.each do |instance|
                plugin = {
                    "name" => instance.name,
                    "code" => instance.plugin.read_code,
                    "options" => instance.settings || {},
                    "timeout" => instance.timeout || 60,
                    "interval" => instance.poll_interval || 0,
                    "id" => instance.id
                }
                plan["plugins"] << plugin
            end
            plan["directives"] = { # FIXME
                "take_snapshots" => true,
                "interval" => self.scout_poll_interval 
            }
            plan
        end
        
        
        def report_admins
            self.admins.reject{ |adm| !adm.receive_notifications }.map{ |adm| adm.admin }
        end
        
        with_mapper do

             def before_save(obj, mode)
                 if mode == :insert
                     if obj.customer
                         obj.customer.admins.each do |customer_adm|
                             obj.admins << Server::Admins.new(
                                :admin => customer_adm.admin,
                                :receive_notifications => customer_adm.receive_notifications,
                                :manage_plugins => customer_adm.manage_plugins
                             )
                         end
                     else
                         global = Admin.where(:global => true)
                         global.each do |adm|
                             obj.admins << adm
                         end
                     end
                 end
                 super
             end

         end
        
        
    end
    
end; end
