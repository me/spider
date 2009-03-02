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
            @cmd.parse
        end

    end

 


end; end