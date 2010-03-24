require 'thread'
require 'fileutils'
require 'apps/worker/lib/runner'
require 'apps/worker/models/job'

module Spider

    module Worker
        @pid_file = Spider.paths[:var]+'/run/worker.pid'
        @script_file = Spider.paths[:config]+'/worker.rb'
        @scripts_dir = Spider.paths[:config]+'/worker'
        @mutex = Mutex.new
        @options = {
            :fork => Spider.conf.get('worker.fork'),
            :detach => Spider.conf.get('worker.detach')
        }
        
        def self.pid_file
            @pid_file
        end
        
        def self.options
            @options
        end
        
        
        def self.app_startup
            
        end
        
        def self.app_startup
            @runner = start_runner unless running?
        end
        
        def self.app_shutdown
            @mutex.try_lock || return
            Spider::Logger.info("Shutting down worker in #{Process.pid}")
            if @runner
                unless @runner == Thread.current
                    @runner.stop
                    @runner = nil
                end
            elsif(File.exist?(@pid_file))
                begin
                    pid = IO.read(@pid_file).to_i
                    unless pid == Process.pid
                        Spider::Logger.info("Sending TERM signal to worker #{pid}")
                        Process::kill 'TERM', pid
                    end
                rescue Errno::ENOENT
                end
            end
            begin
                File.unlink(@pid_file)
            rescue Errno::ENOENT
            end
            @mutex.unlock
        end
        
        def self.start_runner
            start = lambda do
                if @mutex.try_lock
                    return false if File.exist?(@pid_file)
                    FileUtils.mkdir_p(File.dirname(@pid_file))
                    pid_file = File.new(@pid_file, 'w')
                    return false unless pid_file.flock(File::LOCK_EX|File::LOCK_NB) # another istance is creating the worker
                    pid_file << Process.pid
                    pid_file.flock(File::LOCK_UN)
                    pid_file.close
                    Spider::Logger.info("Starting worker #{Process.pid}")
                    @runner = Runner.new
                    if (File.exist?(@script_file))
                        load @script_file
                    end
                    if File.directory?(@scripts_dir)
                        Dir.new(@scripts_dir).each do |script|
                            next if script[0].chr == '.'
                            load @scripts_dir+'/'+script
                        end
                    end
                    Spider.apps.each do |name, mod|
                        if File.directory?(mod.path+'/config/worker')
                            Dir.glob(mod.path+'/config/worker/*.rb').each do |path|
                                file = File.basename(path, '.rb')
                                next if file[0].chr == '.'
                                res = Spider.find_resource(:worker, file, nil, mod)
                                if res
                                    load res.path
                                end
                            end
                        end
                    end
                    @mutex.unlock
                end
            end
            if (options[:fork])
                forked = Spider.fork do
                    $0 = 'spider-worker'
                    trap('TERM') { app_shutdown }
                    trap('INT') { app_shutdown }
                    start.call
                    @runner.join if @runner
                end
                Process.detach(forked) if (options[:detach])
                @runner = nil
            else
                start.call
            end
            return @runner
        end
        
        def self.running?
            return Process.pid if @runner
            
            return false unless File.exist?(@pid_file)
            pid = IO.read(@pid_file).to_i
            begin
                Process::kill 0, pid
                return pid
            rescue Errno::EPERM
                return pid
            rescue Errno::ESRCH
                File.unlink(pid_file)
                return false
            end
        end
        
        def self.in(time, proc_string)
            secs = Rufus.parse_time_string(time)
            self.at(Time.now+secs, proc_string)
        end
        
        def self.at(time, proc_string)
            job = Job.new(:uuid => ::UUID.new.generate, :time => time, :task => proc_string)
            job.save
            return job.uuid
        end
        
        def self.cron(time, params, &proc)
            raise "The cron method must be used only in worker init scripts" unless @runner
            check_params(params) if params
            @runner.cron(time, params)
        end
        
        def self.every(time, params=nil, &proc)
            raise "The every method must be used only in worker init scripts" unless @runner # Only in config?
            check_params(params) if params
            @runner.every(time, params, &proc)
        end
        
        def self.check_params(params)
            raise ArgumentError, "Missing object" unless params[:obj]
            raise ArgumentError, "Missing method" unless params[:method]
            params[:arguments] ||= []
        end
        
        def self.join
            @runner.join if @runner
        end
        
        def self.run_jobs
            Spider::Logger.debug("Worker running jobs queue")
            jobs = Job.where{ (status == nil) & (time <= DateTime.now) }
            jobs.each do |job|
                begin
                    job.run
                    job.status = 'done'
                rescue => exc
                    Spider::Logger.error("Worker job #{job.uuid} failed with error: #{exc.message}")
                    job.status = 'failed'
                end
                job.save
            end
        end

    end


end
