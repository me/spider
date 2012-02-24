require 'spiderfw/http/http'

module Spider::CommandLine

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
                opt.on("--daemonize [daemon_name]", _("Detach server process"), "-d"){ |daemon_name| @daemonize = daemon_name || true }
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
                require 'spiderfw/spider'
                raise "Can't use cgi mode with SSL" if @ssl && @cgi
                if @ssl && @server_name != 'webrick'
                    puts _("Note: Using WEBrick as a webserver, since SSL was requested")
                    @server_name = 'webrick'
                end
                options = {
                    :port => @port,
                    :verbose => $verbose,
                    :ssl => @ssl,
                    :ssl_cert => @ssl_cert,
                    :ssl_key => @ssl_key,
                    :cgi => @cgi,
                    :daemonize => @daemonize
                }
                Spider::HTTP::Server.start(@server_name, options)
                
                
            end
            self.add_command( start )

            # stop


        end

    end

end