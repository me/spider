class ConfigCommand < CmdParse::Command


    def initialize
        super( 'config', true, true )
        @short_desc = _("Manage configuration")
        
        list = CmdParse::Command.new( 'list', false )
        list.short_desc = _("List configuration options")
        list.options = CmdParse::OptionParserWrapper.new do |opt|
        end
        
        list.set_execution_block do |args|
            require 'spiderfw'
            Spider.config.options.sort.each{ |o| puts o }
        end
        
        self.add_command(list)
        
        info = CmdParse::Command.new('info', false)
        info.short_desc = _("Get information about a configuration option")
        info.set_execution_block do |args|
            require 'spiderfw'
            option = Spider.config.option(args.first)
            if option && option[:params]
                print args[0]
                print ":\n"+option[:description]+"\n" if option[:description] && !option[:description].empty?
                puts
                puts "#{(_('Type')+':').ljust(10)} #{option[:params][:type]}" if option[:params][:type]
                default_str = nil
                if default = option[:params][:default]
                    default_str = default.is_a?(Proc) ? _('Dynamic') : default
                end
                puts "#{(_('Default')+':').ljust(10)} #{default_str}" if default_str
                puts "#{(_('Choices')+':').ljust(10)} #{option[:params][:choices].join(', ')}" if option[:params][:choices]
            else
                puts _("Configuration option not found")
            end
        end
        
        self.add_command(info)
        
        get = CmdParse::Command.new('get', false)
        get.short_desc = _("Get the current value of a configuration option")
        get.set_execution_block do |args|
            require 'spiderfw'
            puts Spider.conf.get(args.first)
        end
        
        self.add_command(get)
        
        set = CmdParse::Command.new('set', false)
        set.short_desc = _("Set the value of a configuration option")
        set.set_execution_block do |args|
            require 'spiderfw'
            require 'lib/spiderfw/config/configuration_editor'
            editor = Spider::ConfigurationEditor.new
            Spider.config.loaded_files.each do |f|
                editor.load(f)
            end
            editor.set(*args)
            editor.save
        end
        
        self.add_command(set)
        
    end
    
end
        