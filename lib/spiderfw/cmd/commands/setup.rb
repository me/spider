require 'spiderfw/setup/setup_task'

class SetupCommand < CmdParse::Command


    def initialize
        super( 'setup', false, true )
        @short_desc = _("Setup an application")
#        @description = _("")
        @apps = []
        
        self.options = CmdParse::OptionParserWrapper.new do |opt|
            # TODO
            opt.on("--from [VERSION]", _("Assume a specific version is installed"), "-f"){ |from|
                @from = Gem::Version.new(from)
            }
            opt.on("--to [VERSION]", _("Setup to a specific version"), "-t"){ |to|
                @to = Gem::Version.new(to)
            }
            opt.on("--all", _("Setup all active apps")){ |all|
                @all = true
            }
        end

        set_execution_block do |apps|
            require 'spiderfw'
            apps = Spider.apps.keys if @all
            if (apps.length > 1) && (@to || @from)
                raise "Can't use --from or --to with multiple apps"
            end
            apps.each do |name|
                Spider.load_app(name) unless Spider.apps[name]
                app = Spider.apps[name]
                path = app.setup_path
                current = @from || app.installed_version
                new_version = @to || app.version
                next unless File.exist?(path)
                Dir.entries(path).sort.each do |entry|
                    next if (entry[0].chr == '.')
                    task = Spider::SetupTask.load("#{path}/#{entry}")
                    next unless task
                    next if current && task.version < current
                    next if new_version && task.version > new_version
                    Spider.logger.info("Running setup task #{path+'/'+entry}")
                    task.up
                end
                app.installed_version = app.version
            end 
        end


    end

end