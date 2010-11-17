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
            opt.on("--daemonize", _("Detach server process"), "-d"){ @daemonize = true }
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
            if @ssl && @server_name != 'webrick'
                puts _("Note: Using WEBrick as a webserver, since SSL was requested")
                @server_name = 'webrick'
            end
            @port ||= Spider.conf.get('webserver.port')
            @server_name ||= Spider.conf.get('http.server')
            @pid_file = Spider.paths[:var]+'/run/server.pid'
            puts _("Using webserver %s") % @server_name if $verbose
            puts _("Listening on port %s") % @port if $verbose
            server = Spider::HTTP.const_get(servers[@server_name]).new
            ssl_server = nil
            start = lambda{
                Spider.startup
                if Spider.conf.get('devel.trace.extended')
                    require 'ruby-debug'
                    require 'spiderfw/utils/monkey/debugger'
                    Debugger.start
                    Debugger.post_mortem
                end
                
                thread = Thread.new do
                    server.start(:port => @port, :cgi => @cgi)
                end
                if (@ssl)
                    @ssl_cert ||= Spider.conf.get('orgs.default.cert')
                    @ssl_key ||= Spider.conf.get('orgs.default.private_key')
                    raise "SSL Certificate not set" unless @ssl_cert
                    raise "SSL Key not set" unless @ssl_key
                    raise "SSL Certificate (#{@ssl_cert}) not found" unless File.file?(@ssl_cert)
                    raise "SSL Key (#{@ssl_key}) not found" unless File.file?(@ssl_key)
                    ssl_thread = Thread.new do
                        ssl_server = Spider::HTTP.const_get(servers[@server_name]).new
                        ssl_server.start(:port => @ssl, :ssl => true, :ssl_cert => @ssl_cert, :ssl_private_key => @ssl_key)
                    end
                end
                do_shutdown = lambda{ |arg|
                    server.shutdown
                    ssl_server.shutdown if ssl_server
                    Spider.shutdown
                    begin
                        File.unlink(@pid_file)
                    rescue Errno::ENOENT
                    end
                }
                trap('TERM', &do_shutdown)
                trap('INT', &do_shutdown)
                
                thread.join
                ssl_thread.join if ssl_thread
            }
            if (@daemonize)
                forked = Spider.fork do
                    File.open(@pid_file, 'w') do |f|
                        f.write(Process.pid)
                    end
                    $0 = 'spider-server'
                    start.call
                end
                Process.detach(forked)
            else
                start.call
            end
        end
        self.add_command( start )

        # stop


    end

end