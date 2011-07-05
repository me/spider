require 'cmdparse'

module Spider; module Master

    class Cmd < ::CmdParse::Command

        def initialize
            super('master', true)
            
            update_averages = CmdParse::Command.new('averages', false )
            update_averages.short_desc = _("Update report averages")
            update_averages.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.on("--instance id", _("Plugin instance id"), "-i"){ |i| @instance_id = i }
                opt.on("--server id", _("Server id"), "-s"){ |i| @server_id = i }
                opt.on("--type t", _("Average type (hour, day, week)"), "-t"){ |t| @type = t.to_sym }
                opt.on("--days n", _("Compute averages until n days ago"), "-d"){ |d| @days = d.to_i }
            end
            
            update_averages.set_execution_block do
                @days ||= 7
                @type ||= :hour
                instances = []
                unless @instance_id || @server_id
                    puts _("Please provide an instance id or a server id")
                    exit
                end
                if @instance_id
                    instances = [@instance_id]
                elsif @server_id
                    instances = ScoutPluginInstance.where{ |i| (i.server == @server_id) }.map{ |i| i.id }
                # else
                #     instances = ScoutPluginInstance.all.map{ |i| i.id }
                end
                instances.each do |i|
                    update_averages(i, @days, @type)
                end
                    
            end
            self.add_command(update_averages)
            
            
            
        end
        
        def update_averages(instance_id, days_back, type= :hour)
            last = Date.today - days_back
            i = ScoutPluginInstance.new(instance_id)
            puts _("Updating averages for %s until #{last}") % i.to_s
            i.fields_to_averages(last, type)
        end

    end

 


end; end