require 'rack'
require 'spiderfw/http/adapters/rack'

module Spider; module HTTP
    
    class Server
        
        @supports = {
            :chunked_request => false,
            :ssl => false
        }

        def self.supports?(capability)
            @supports[capability]
        end

        
        def options(opts={})
            defaults = {
                :host => '0.0.0.0',
                :port => 8080
            }
            return defaults.merge(opts)
        end
        
        def start(opts={})
            @options = opts
            Spider.logger.info{ "Routes: \n"+Spider::HomeController.print_app_routes }
            start_server(opts)
        end
        
        def shutdown
            Spider.logger.info("Webserver shutdown");
            shutdown_server            
        end
        
        def request_received
        end

        def self.get_opts(server_name, options)
            server_name ||= Spider.conf.get('http.server')
            options[:port] ||= Spider.conf.get('webserver.port')
            opts = {
                :server => server_name,
                :Port => options[:port],
                :config => File.join(Spider.paths[:root], 'config.ru')
            }
            case server_name
            when 'thin'
                opts[:threaded] = true unless options[:no_threads]
                options[:daemonize] = true
            end
            opts[:app] = Spider::HTTP::RackApplication.new unless File.file?(opts[:config])
            ssl_opts = nil
            if options[:ssl]
                require 'openssl'
                options[:ssl_cert] ||= Spider.conf.get('orgs.default.cert')
                options[:ssl_key] ||= Spider.conf.get('orgs.default.private_key')
                raise "SSL Certificate not set" unless options[:ssl_cert]
                raise "SSL Key not set" unless options[:ssl_key]
                raise "SSL Certificate (#{options[:ssl_cert]}) not found" unless File.file?(options[:ssl_cert])
                raise "SSL Key (#{options[:ssl_key]}) not found" unless File.file?(options[:ssl_key])
                ssl_opts = opts.clone
                ssl_opts[:Port] = options[:ssl]
                private_key = OpenSSL::PKey::RSA.new(File.open(options[:ssl_key]).read)
                certificate = OpenSSL::X509::Certificate.new(File.open(options[:ssl_cert]).read)
                case server_name
                when 'webrick'
                    require 'webrick/https'
                    ssl_opts[:SSLEnable] = true
                    ssl_opts[:SSLVerifyClient] = ::OpenSSL::SSL::VERIFY_NONE
                    ssl_opts[:SSLCertificate] = certificate
                    ssl_opts[:SSLPrivateKey] = private_key
                # when 'thin'
                #     ssl_opts[:ssl] = true
                #     ssl_opts[:verify_peer] = ::OpenSSL::SSL::VERIFY_NONE
                #     ssl_opts[:ssl_key_file] = private_key
                #     ssl_opts[:ssl_cert_file] = certificate
                else
                    raise "SSL not supported with #{server_name} server"
                end
            end
            return [opts, ssl_opts]
        end
        
        def self.start(server_name, options={})
            start = lambda{
                
                
                pid_file = File.join(Spider.paths[:var], 'run/server.pid')
                puts _("Using webserver %s") % server_name if options[:verbose]
                puts _("Listening on port %s") % opts[:port] if options[:verbose]
                rack = nil
                ssl_rack = nil
                server = nil
                ssl_server = nil

                require 'spiderfw/init'
                Spider.logger.info{ "Routes: \n"+Spider::HomeController.print_app_routes }
                Spider.startup
                opts, ssl_opts = self.get_opts(server_name, options)
                
                if opts
                    thread = Thread.new do
                        rack = Rack::Server.start(opts)
                        server = rack.server if rack
                    end
                    $stdout << "Spider server running on port #{opts[:Port]}\n"
                end
                
                if ssl_opts
                    ssl_thread = Thread.new do
                        ssl_rack = Rack::Server.start(ssl_opts)
                        ssl_server = ssl_rack.server if ssl_rack
                    end
                end
                do_shutdown = lambda{
                    Debugger.post_mortem = false if defined?(Debugger)
                    server.shutdown if server
                    ssl_server.shutdown if ssl_server
                    pid_file = File.join(Spider.paths[:var], 'run/server.pid')
                    begin
                        File.unlink(pid_file)
                    rescue Errno::ENOENT
                    end
                }
                Spider.on_shutdown(&do_shutdown)
                
                begin
                    thread.join if thread
                    ssl_thread.join if ssl_thread
                rescue SystemExit
                end
            }
            if options[:daemonize]
                require 'spiderfw/init'
                require 'spiderfw/utils/fork'
                pid_file = File.join(Spider.paths[:var], 'run/server.pid')
                process_name = (options[:daemonize] == true) ? 'spider-server' : options[:daemonize]
                forked = Spider.fork do
                    File.open(pid_file, 'w') do |f|
                        f.write(Process.pid)
                    end
                    $SPIDER_SCRIPT ||= $0
                    $0 = process_name
                    STDIN.reopen "/dev/null"       # Free file descriptors and
                    STDOUT.reopen "/dev/null", "a" # point them somewhere sensible
                    STDERR.reopen STDOUT           # STDOUT/STDERR should go to a logfile
                    start.call
                end
                Process.detach(forked)
            else
                Spider.init_base
                spawner_started = false
                if Spider.conf.get('webserver.respawn_on_change')
                    Spider.start_loggers
                    begin
                        gemfile = File.join(Spider.paths[:root], 'Gemfile')
                        gemfile_lock = File.join(Spider.paths[:root], 'Gemfile.lock')
                        if File.file?(gemfile) && File.file?(gemfile_lock)
                            require 'bundler'
                            Bundler.require :default, Spider.runmode.to_sym
                        end
                        spawner = Spawner.new({'spawn' => start})
                        spawner.run('spawn')
                        spawner_started = true
                    rescue LoadError => exc
                        raise unless exc.message =~ /fssm/
                        Spider.logger.error("Install 'fssm' gem to enable respawning")
                    end
                end
                unless spawner_started
                    Spider.main_process_startup
                    Spider.startup
                    begin
                        start.call 
                    rescue Exception => exc
                        Spider.logger.error(exc)
                    end
                end
            end
        end
        
    end
    
    class Spawner
        attr_reader :child_pid
        
        def initialize(actions)
            @actions = actions
        end
        
        def run(action=nil)
            @monitor_thread = monitor_fs
            spawn(action)
            @monitor_thread.join
        end
        
        def spawn(action)
            rd, wr = IO.pipe
            if pid = fork
                # Spawner
                Spider.logger.debug("Spawner forked")
                @child_pid = pid

                unless @already_forked
                    Spider.main_process_startup
                    exit_spawner = lambda{ 
                        Spider.logger.debug "Spawner exiting" 
                        Process.kill 'KILL', @monitor_thread[:spawner_child_pid]
                    }
                    Spider.on_main_process_shutdown(&exit_spawner)
                    $SPIDER_SCRIPT ||= $0
                    $0 = 'spider-spawner'
                end
                @already_forked = true

                wr.close
                @monitor_thread[:spawner_child_pid] = pid
                # TODO
                # msg = rd.read(5)
                # rd.close
                # spawn(msg) unless msg.blank?

            else
                # Child
                $SPIDER_SPAWNED = true
                trap('TERM'){ }
                trap('INT'){ }
                rd.close
                Spider.spawner = wr
                return unless @actions[action]
                begin
                    @actions[action].call
                rescue Exception => exc
                    Spider.logger.debug(exc)
                    Process.kill 'KILL', Process.pid
                end
            end
        end
        
        def monitor_fs
            require 'fssm'
            spawner = self
            action = 'spawn'
            return Thread.new do
                fsm_exclude = ['var', 'tmp']
                FSSM.monitor do
                    #Spider.logger.debug("Monitoring #{Spider.paths[:apps]} for changes")
                    path Spider.paths[:apps] do 
                        glob '**/*.rb'

                        update { |base, relative| 
                            Spider.logger.debug("#{relative} updated, restarting")
                            Process.kill 'KILL', Thread.current[:spawner_child_pid]
                            spawner.spawn(action)
                        }
                        delete { |base, relative|
                            Spider.logger.debug("#{relative} deleted, restarting")
                            Process.kill 'KILL', Thread.current[:spawner_child_pid]
                            spawner.spawn(action)
                        }
                        create { |base, relative|
                            Spider.logger.debug("#{relative} created, restarting")
                            Process.kill 'KILL', Thread.current[:spawner_child_pid]
                            spawner.spawn(action)
                        }
                    end
                    # path Spider.paths[:root] do
                    #     glob '**/*.shtml'
                    #     
                    #     update { |base, relative|
                    #         puts "Changed #{base}, #{relative}"
                    #         Spider::Template.cache.invalidate(File.join('ROOT', relative))
                    #     }
                    # end

                    # path '/some/other/directory/' do
                    #   update {|base, relative|}
                    #   delete {|base, relative|}
                    #   create {|base, relative|}
                    # end
                end
            end
            
        end
        
    end
    
end; end
