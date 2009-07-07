require 'rubygems'
require 'spiderfw/i18n/gettext'
require 'cmdparse'
require 'spiderfw/cmd/commands/webserver'
require 'spiderfw/cmd/commands/init'
require 'spiderfw/cmd/commands/console'
require 'spiderfw/cmd/commands/test'
require 'spiderfw/cmd/commands/setup'
require 'spiderfw/cmd/commands/model'

module Spider; module CommandLine

    class Cmd

        def initialize
            @cmd = CmdParse::CommandParser.new( true, true )
            @cmd.program_name = "spider"
            @cmd.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.separator _("Global options:")
                opt.on("--verbose", _("Be verbose when outputting info"), "-v" ) {|t| $verbose = true }
                opt.on("--chdir", _("Cd to a directory before running"), "-c"){ |c| Dir.chdir(c) }
                opt.on("--sets SETS", Array, _("Include configuration sets"), "-s"){ |sets|
                    $SPIDER_CONFIG_SETS = sets
                }
                opt.on("--devel", _("Set runmode to devel"), "-d") do 
                    $SPIDER_RUNMODE = 'devel'
                    Spider.runmode = 'devel' if Spider
                end
            end

            @cmd.add_command(CmdParse::HelpCommand.new, true)
            @cmd.add_command(WebServerCommand.new)
            @cmd.add_command(InitCommand.new)
            @cmd.add_command(ConsoleCommand.new)
            begin
                require 'spiderfw/cmd/commands/cert'
                @cmd.add_command(CertCommand.new)
            rescue LoadError
            end
            @cmd.add_command(TestCommand.new)
            @cmd.add_command(SetupCommand.new)
            @cmd.add_command(ModelCommand.new)
            # @cmd.add_command(ScaffoldCommand.new)
        end

        def parse
            cmd_name = ARGV[0]
            cmd_name = ARGV[1] if (cmd_name == 'help')
            require 'ruby-debug'
            if !@cmd.main_command.commands[cmd_name]
                require 'spiderfw'
                if Spider.apps_by_short_name[cmd_name] && Spider.apps_by_short_name[cmd_name].const_defined?(:Cmd)
                    app_cmd = Spider.apps_by_short_name[cmd_name].const_get(:Cmd).new
                    @cmd.add_command(app_cmd)
#                    app_cmd.add_command(CmdParse::HelpCommand.new, true)
                end
            end
            @cmd.parse
        end

    end

 


end; end