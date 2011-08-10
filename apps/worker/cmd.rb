require 'cmdparse'

module Spider; module Worker

    class Cmd < ::CmdParse::Command

        def initialize
            super( 'worker', true)
            
            status = CmdParse::Command.new('status', false )
            status.short_desc = _("Check worker process status")
            status.set_execution_block do
                pid = Worker.running?
                if (pid)
                    str = "Worker running (#{pid})"
                    if Worker.pid_file && ::File.exists?(Worker.pid_file)
                        str += " since #{::File::Stat.new(Worker.pid_file).mtime}"
                    end
                    puts str
                else
                    puts "Worker not running"
                end
            end
            self.add_command(status)
            
            start = CmdParse::Command.new('start', false)
            start.short_desc = _("Start worker")
            start.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.on("--daemonize", _("Daemonize worker"), "-d"){ |d|
                    @daemonize = true
                }
            end
            start.set_execution_block do
                if (@daemonize)
                    Worker.options[:fork] = true
                    Worker.options[:detach] = true
                else
                    Worker.options[:fork] = false
                    Worker.options[:detach] = false
                end
                Spider.conf.set('worker.enable', true)
                #Worker.start
                Spider.main_process_startup
                if (@daemonize)
                    Worker.start
                    STDIN.reopen "/dev/null"       # Free file descriptors and
                    STDOUT.reopen "/dev/null", "a" # point them somewhere sensible
                    STDERR.reopen STDOUT           # STDOUT/STDERR should go to a logfile
                else
                    Spider.startup
                    Worker.join
                    # trap('TERM') { Spider.shutdown; exit }
                    # trap('INT') { Spider.shutdown; exit }
                    # Worker.join
                end
            end
            self.add_command(start)
            
            stop = CmdParse::Command.new('stop', false)
            stop.short_desc = _("Stop worker")
            stop.set_execution_block do
                Spider.shutdown
            end
            self.add_command(stop)
            
            
        end

    end

 


end; end
