require 'spiderfw/http/http'

class WebServerCommand < CmdParse::Command


    def initialize
        super( 'webserver', true, true )
        @short_desc = _("Manage internal webserver")
        @description = _("")
        
        @port = 8080

        # start
        start = CmdParse::Command.new( 'start', false )
        start.short_desc = "Start web server"
        start.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--port N", _("The port the webserver should listen on"), "-p") { |port|
                @port = port
            }
        end
        start.set_execution_block do |args|
            server_type = 'webrick'
            #server_type = Spider.conf.get('webserver.server')
            puts _("Using webserver %s") % server_type if $verbose
            puts _("Listening on port %s") % @port if $verbose
            case server_type
            when 'webrick'
                server = Spider::HTTP::WEBrick.new()
                server.start(:port => @port)
            end
        end
        self.add_command( start )

        # stop


    end

end