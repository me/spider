require 'cmdparse'
require 'apps/servant/lib/client'

module Spider; module Servant

    class Cmd < ::CmdParse::Command
        
        def initialize
            super('servant', true)
            
            ping = CmdParse::Command.new('ping', false )
            ping.short_desc = _("Ping server")
            ping.set_execution_block do |args|
                require 'spiderfw/spider'
                Spider.init_base
                url = args.first || Spider.config.get('spider.master.url')
                unless url
                    puts _("No url provided, exiting.")
                    exit
                end
                servant = Spider::Servant::Client.new(url)
                servant.ping_server
            end
            self.add_command(ping)
    
            
        end
        
    end
    
end; end