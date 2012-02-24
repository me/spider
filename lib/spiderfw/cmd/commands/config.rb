module Spider::CommandLine

    class ConfigCommand < CmdParse::Command


        def initialize
            super( 'config', true, true )
            @short_desc = _("Manage configuration")
            
            list = CmdParse::Command.new( 'list', false )
            list.short_desc = _("List configuration options")
            list.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.on("--info", _("Show info"), "-i"){ |i|
                    @info = true
                }
            end
            
            list.set_execution_block do |args|
                require 'spiderfw/spider'
                Spider.init_base
                search = args.first
                max_len = 0
                opts = Spider.config.options_list
                opts.each{ |o| max_len = o.length if o.length > max_len }
                opts.sort.each{ |o| 
                    next if search && o.index(search) != 0
                    str = o.ljust(max_len + 2)
                    if @info
                        option = Spider.config.option(o)
                        str += " #{option[:description]}" if option
                    end
                    puts str
                }
            end
            
            self.add_command(list)
            
            info = CmdParse::Command.new('info', false)
            info.short_desc = _("Get information about a configuration option")
            info.set_execution_block do |args|
                require 'spiderfw/spider'
                Spider.init_base
                option = Spider.config.option(args.first)
                if option && option[:params]
                    print args[0]
                    print ":\n"+option[:description]+"\n" if option[:description] && !option[:description].empty?
                    puts
                    puts "#{( _('Type') +':').ljust(10)} #{option[:params][:type]}" if option[:params][:type]
                    default_str = nil
                    if default = option[:params][:default]
                        default_str = default.is_a?(Proc) ? _('Dynamic') : default
                    end
                    puts "#{( _('Default') +':').ljust(10)} #{default_str}" if default_str
                    if choices = option[:params][:choices]
                        choices = choices.call if choices.is_a?(Proc)
                        puts "#{( _('Choices') +':').ljust(10)} #{choices.join(', ')}" 
                    end
                else
                    puts _("Configuration option not found")
                end
            end
            
            self.add_command(info)
            
            get = CmdParse::Command.new('get', false)
            get.short_desc = _("Get the current value of a configuration option")
            get.set_execution_block do |args|
                require 'spiderfw/spider'
                Spider.init_base
                puts Spider.conf.get(args.first)
            end
            
            self.add_command(get)
            
            set = CmdParse::Command.new('set', false)
            set.short_desc = _("Set the value of a configuration option")
            set.set_execution_block do |args|
                require 'spiderfw/spider'
                require 'lib/spiderfw/config/configuration_editor'
                Spider.init_base
                editor = Spider.config.get_editor
                editor.set(*args)
                editor.save
            end
            
            self.add_command(set)
            
        end
        
    end

end