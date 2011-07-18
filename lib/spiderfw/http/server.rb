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
        
        def self.start(server_name, port, options={})
            servers = {
                'webrick'   => :WEBrick,
                'mongrel'   => :Mongrel,
                'thin'      => :Thin
            }
            
            start = lambda{
                $SPIDER_WEB_SERVER = true
                require 'spiderfw'
                require 'spiderfw/controller/http_controller'
                
                port ||= Spider.conf.get('webserver.port')
                server_name ||= Spider.conf.get('http.server')
                pid_file = File.join(Spider.paths[:var], 'run/server.pid')
                puts _("Using webserver %s") % server_name if options[:verbose]
                puts _("Listening on port %s") % port if options[:verbose]
                server = Spider::HTTP.const_get(servers[server_name]).new
                ssl_server = nil
                Spider.startup
                if Spider.conf.get('devel.trace.extended')
                    require 'ruby-debug'
                    require 'spiderfw/utils/monkey/debugger'
                    Debugger.start
                    Debugger.post_mortem
                end
                
                thread = Thread.new do
                    server.start(:port => port, :cgi => options[:cgi])
                end
                $stdout << "Spider server running on port #{port}\n"
                if options[:ssl]
                    options[:ssl_cert] ||= Spider.conf.get('orgs.default.cert')
                    options[:ssl_key] ||= Spider.conf.get('orgs.default.private_key')
                    raise "SSL Certificate not set" unless options[:ssl_cert]
                    raise "SSL Key not set" unless options[:ssl_key]
                    raise "SSL Certificate (#{options[:ssl_cert]}) not found" unless File.file?(options[:ssl_cert])
                    raise "SSL Key (#{options[:ssl_key]}) not found" unless File.file?(options[:ssl_key])
                    ssl_thread = Thread.new do
                        ssl_server = Spider::HTTP.const_get(servers[server_name]).new
                        ssl_server.start(:port => options[:ssl], :ssl => true, 
                            :ssl_cert => options[:ssl_cert], :ssl_private_key => options[:ssl_key])
                    end
                end
                do_shutdown = lambda{
                    Debugger.post_mortem = false
                    # debugger
                    server.shutdown
                    ssl_server.shutdown if ssl_server
                    pid_file = File.join(Spider.paths[:var], 'run/server.pid')
                    begin
                        File.unlink(pid_file)
                    rescue Errno::ENOENT
                    end
                }
                Spider.on_shutdown(&do_shutdown)
                
                thread.join
                ssl_thread.join if ssl_thread
            }
            if options[:daemonize]
                require 'spiderfw'
                require 'spiderfw/utils/fork'
                pid_file = File.join(Spider.paths[:var], 'run/server.pid')
                process_name = (options[:daemonize] == true) ? 'spider-server' : options[:daemonize]
                forked = Spider.fork do
                    File.open(pid_file, 'w') do |f|
                        f.write(Process.pid)
                    end
                    $SPIDER_PROC_NAME ||= $0
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
                        begin
                            Bundler.require :default, Spider.runmode.to_sym
                        rescue
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
                    start.call 
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
                    Spider.main_process_startup
                    $SPIDER_PROC_NAME ||= $0
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
                @actions[action].call
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