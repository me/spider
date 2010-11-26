require 'rubygems'
require 'spiderfw/i18n/gettext'
require 'cmdparse'
require 'spiderfw/cmd/commands/webserver'
require 'spiderfw/cmd/commands/create'
require 'spiderfw/cmd/commands/console'
require 'spiderfw/cmd/commands/test'
require 'spiderfw/cmd/commands/setup'
require 'spiderfw/cmd/commands/model'
require 'spiderfw/cmd/commands/config'
require 'spiderfw/cmd/commands/content'
require 'spiderfw/cmd/commands/app'

module Spider; module CommandLine

    class Cmd

        def initialize
            @cmd = CmdParse::CommandParser.new( true, true )
            @cmd.program_name = "spider"
            @cmd.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.separator _("Global options:")
                opt.on("--version", _("Output Spider version and exit"), "-v"){ |v| 
                    require 'spiderfw/version'
                    puts Spider::VERSION
                    exit
                }
                opt.on("--verbose", _("Be verbose when outputting info"), "-V" ) {|t| $verbose = true }
                opt.on("--chdir", _("Cd to a directory before running"), "-c"){ |c| Dir.chdir(c) }
                opt.on("--sets SETS", Array, _("Include configuration sets"), "-s"){ |sets|
                    $SPIDER_CONFIG_SETS = sets
                }
                opt.on("--devel", _("Set runmode to devel"), "-d") do
                    $SPIDER_RUNMODE = 'devel'
                    Spider.runmode = 'devel' if Spider && Spider.respond_to?(:runmode=)
                end
                opt.on("--http-proxy [PROXY]", _("Proxy server to use for http operations (http://user:pass@host:port)")){ |p|
                    ENV['http_proxy'] = p
                }
            end

            @cmd.add_command(CmdParse::HelpCommand.new, true)
            @cmd.add_command(WebServerCommand.new)
            @cmd.add_command(CreateCommand.new)
            @cmd.add_command(ConsoleCommand.new)
            begin
                require 'spiderfw/cmd/commands/cert'
                @cmd.add_command(CertCommand.new)
            rescue LoadError
            end
            @cmd.add_command(TestCommand.new)
            @cmd.add_command(SetupCommand.new)
            @cmd.add_command(ModelCommand.new)
            @cmd.add_command(ConfigCommand.new)
            @cmd.add_command(ContentCommand.new)
            @cmd.add_command(AppCommand.new)
            # @cmd.add_command(ScaffoldCommand.new)
        end

        def parse
            cmd_name = nil
            0.upto(ARGV.length) do |i|
                if (ARGV[i] && ARGV[i] != 'help' && ARGV[i][0].chr != '-')
                    cmd_name = ARGV[i]
                    break
                end
            end
            cmd_name ||= 'help'
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