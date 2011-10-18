require 'uuidtools'
require 'apps/servant/lib/client'
require 'apps/servant/lib/commands_processor'

module Spider

    module Servant

        def self.command_processor
            @command_processor ||= Spider::Servant::CommandsProcessor
        end
        
        def self.command_processor=(klass)
            @command_processor = klass
        end

        def self.install_id
            uuid_file = File.join(Spider.paths[:var], 'install_id')
            return File.read(uuid_file) if File.exists?(uuid_file)
            uuid = UUIDTools::UUID.random_create.to_s
            File.open(uuid_file, 'w'){ |f| f << uuid }
            uuid
        end
        
        def self.status
            Spider.init_base
            apps = self.apps
            status = {
                :install_id => self.install_id,
                :apps => apps
            }
        end
        
        def self.apps
            active = Spider.config.get('apps')
            apps = Spider.home.apps
            h = {}
            apps.each do |k, v|
                h[k] = {}
                h[k][:version] = v[:spec].version if v[:spec]
                h[k][:active] = true if active.include?(k)
            end
            h
        end
        
        def self.gather_log(level=:WARN)
            level = level.to_s
            levels = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']
            lev = levels.index(level)
            
            log_file = File.join(Spider.paths[:log], Spider.conf.get('log.file_name'))
            return [] unless File.exists?(log_file)
            log_prev_file = File.join(Spider.paths[:var], 'memory', 'servant_log_prev')
            previous_position = 0
            if File.exists?(log_prev_file)
                previous_position = File.read(log_prev_file).to_i
            end
            current_position = open(log_file){ |fd| fd.stat.size }
            if current_position < previous_position
                previous_position = 0
            end
            
            log_line = /\w, \[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}) \#(\d+):(-?\d+)\] ([\s\w]{5}) -- : (.+)/
            lines = []

            File.open(log_file, 'rb') do |f| 
                # seek to the last position in the log file
                f.seek(previous_position, IO::SEEK_SET)
                cnt = 0
                f.each_line do |line|
                    prev_cnt = cnt
                    cnt += line.length
                    parts = log_line.match(line)
                    next unless parts
                    m, time, pid, thread, severity, details = *parts
                    sev = levels.index(severity.strip)
                    next unless sev
                    next unless sev >= lev
                    lines << [time, severity.strip, details]
                end

            end # File.open
            File.open(log_prev_file, 'w'){ |f| f << current_position}
            lines
        end
        
        def self.gather_configuration
            res = ""
            first = true
            Dir.glob(File.join(Spider.paths[:config], '*.yml')).each do |f|
                res << "\n\n" unless first
                res << File.read(f)
                first = false
            end
            res
        end
    
    end
    
end