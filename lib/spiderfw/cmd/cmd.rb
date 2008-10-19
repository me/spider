require 'cmdparse'
require 'spiderfw/cmd/commands/webserver'
require 'spiderfw/cmd/commands/init'

module Spider; module CommandLine

    class Cmd

        def initialize
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
            # @cmd.add_command(ModelCommand.new)
            # @cmd.add_command(ScaffoldCommand.new)
        end

        def parse
            @cmd.parse
        end

    end

 


end; end