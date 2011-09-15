module Spider; module Servant
    
    class CommandsProcessor
        attr_reader :client
        
        def self.plan_file
            File.join(Spider.paths[:var], 'servant_command_plan')
        end
        
        def self.progress_file
            File.join(Spider.paths[:var], 'servant_command_progress')
        end
        
        def self.save_plan(commands)
            File.open(self.plan_file, 'w'){ |f| f << commands.to_json }
        end
        
        def self.read_plan
            return nil unless File.exists?(self.plan_file)
            JSON.parse(File.readfile(self.plan_file))
        end
        
        def self.unfinished_plan?
            File.exists?(self.plan_file)
        end
        
        def initialize(master_url)
            @url = master_url
            @client = Servant::Client.new(@url)
            @progress = {}
        end
        
        def resume_plan
            plan = self.class.read_plan
            progress = JSON.parse(File.read(self.progress_file)) if File.exists?(self.progress_file)
            progress ||= {}
            plan.reject!{ |c| progress[c['id']] }
            process_commands(plan)
        end
        
        def save_progress
            File.open(self.class.progress_file, 'w'){ |f| f << @progress.to_json }
        end
        
        def run_commands(commands)
            self.class.save_plan(commands)
            process_commands(commands)
        end
        
        def process_commands(commands)
            results = []
            error = nil
            commands.each do |command|
                command_result = {:command_id => command['id']}
                if error
                    command_result[:previous_error] = true
                else
                    begin
                        command_result[:res] = execute_command(command)
                    rescue => exc
                        error = exc.message
                        command_result[:error] = error
                    end
                end
                results << command_result
            end
            self.client.send_event(:plan_done, {:results => results})
            File.unlink(self.class.plan_file) if File.exists?(self.class.plan_file)
            File.unlink(self.class.progress_file) if File.exists?(self.class.progress_file)
        end
        
        def execute_command(command)
            args = command["arguments"]
            res = case command["name"]
            when "gems"
                install_gems(args)
            when "apps"
                install_apps(args)
            when "configure"
                
            end
            @progress[command['id']] = true
            save_progress
            self.client.send_event(:command_done, {:id => command['id'], :res => res})
            res
        end
        
        def install_gems(gems)
            inst = Gem::DependencyInstaller.new
            installed = []
            gems.each do |g|
                v = g['version'] || Gem::Requirement.default
                unless Spider.gem_available?(g['name'], v)
                    inst.install g['name'], v
                    installed << g
                end
                
            end
            return {:installed => gems}
        end
        
        def install_apps(apps)
            require 'spiderfw/setup/app_manager'
            Spider::AppManager.get_apps(apps)
        end
        
    end
    
end; end