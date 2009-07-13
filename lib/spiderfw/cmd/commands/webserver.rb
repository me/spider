require 'spiderfw/http/http'

class WebServerCommand < CmdParse::Command


    def initialize
        super( 'webserver', true, true )
        @short_desc = _("Manage internal webserver")
#        @description = _("")
        
        servers = {
            'webrick' => :WEBrick,
            'mongrel' => :Mongrel,
            'thin' => :Thin
        }

        # start
        start = CmdParse::Command.new( 'start', false )
        start.short_desc = "Start web server"
        start.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--port N", _("The port the webserver should listen on"), "-p") { |port|
                @port = port
            }
            opt.on("--server name", _("Which webserver to use; the choices are 'webrick', 'mongrel' and 'thin'"), "-s"){ |server_name|
                raise CmdParse::InvalidArgumentError, _("The webserver %s is not supported") % server_name unless servers[server_name]
                @server_name = server_name
            }
            opt.on("--cgi", _("Serve each request spawning a CGI subprocess. Useful in developement."), "-c"){
                @cgi = true
            }
            opt.on("--ssl [PORT]", _("Listen to SSL requests"), "-S"){ |port|
                @ssl = port || 443
            }
            opt.on("--cert CERT", _("SSL certificate")){ |cert| @ssl_cert = cert }
            opt.on("--key key", _("SSL private key")){ |key| @ssl_key = key }
        end
        start.set_execution_block do |args|
            require 'spiderfw'
            raise "Can't use cgi mode with SSL" if @ssl && @cgi
            @port ||= Spider.conf.get('webserver.port')
            @server_name ||= Spider.conf.get('http.server')
            puts _("Using webserver %s") % @server_name if $verbose
            puts _("Listening on port %s") % @port if $verbose
            server = Spider::HTTP.const_get(servers[@server_name]).new
            thread = Thread.new do
                server.start(:port => @port, :cgi => @cgi)
            end
            if (@ssl)
                ssl_thread = Thread.new do
                    server.start(:port => @ssl, :ssl => true)
                end
            end
            thread.join
            ssl_thread.join if ssl_thread
            
        end
        self.add_command( start )

        # stop


    end

end