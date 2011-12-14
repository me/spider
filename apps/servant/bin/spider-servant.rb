#!/usr/bin/env ruby
require 'rubygems'
require 'spiderfw/init'
require 'cmdparse'
require $SPIDER_PATH+'/apps/servant/lib/servant.rb'
require 'ruby-debug'


class Cmd

    def initialize
        @cmd = CmdParse::CommandParser.new( true, true )
        @cmd.program_name = "spider-servant"
        @cmd.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.separator _("Global options:")
            opt.on("--verbose", _("Be verbose when outputting info"), "-v" ) {|t| $verbose = true }
            opt.on("--config-file [FILE]", _("Configuration file"), "-c"){ |c| @config_file = c }
        end

        ping_server = CmdParse::Command.new('ping_server', false)
        ping_server.set_execution_block do |args|
            servant = Spider::Servant::Servant.new(@config_file)
            servant.ping_server
        end


        @cmd.add_command(CmdParse::HelpCommand.new, true)
        @cmd.add_command(ping_server)

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
        @cmd.parse
    end

end

cmd = Cmd.new
cmd.parse
exit