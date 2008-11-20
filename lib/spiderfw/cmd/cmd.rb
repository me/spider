require 'cmdparse'
require 'spiderfw/cmd/commands/webserver'
require 'spiderfw/cmd/commands/init'
require 'spiderfw/cmd/commands/console'
require 'spiderfw/cmd/commands/cert'
require 'spiderfw/cmd/commands/test'
require 'spiderfw/cmd/commands/setup'

module Spider; module CommandLine

    class Cmd

        def initialize
            Spider.init
            @cmd = CmdParse::CommandParser.new( true, true )
            @cmd.program_name = "spider"
            #@cmd.program_version = Spider.version.split('.')
            @cmd.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.separator _("Global options:")
                opt.on("--verbose", _("Be verbose when outputting info"), "-v" ) {|t| $verbose = true }
            end

            @cmd.add_command(CmdParse::HelpCommand.new, true)
            @cmd.add_command(WebServerCommand.new)
            @cmd.add_command(InitCommand.new)
            @cmd.add_command(ConsoleCommand.new)
            @cmd.add_command(CertCommand.new)
            @cmd.add_command(TestCommand.new)
            @cmd.add_command(SetupCommand.new)
            # @cmd.add_command(ModelCommand.new)
            # @cmd.add_command(ScaffoldCommand.new)
        end

        def parse
            @cmd.parse
        end

    end

 


end; end