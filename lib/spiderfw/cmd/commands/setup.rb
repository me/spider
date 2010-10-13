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
            opt.on("--version [VERSION]", _("Only run the setup script for the given version"), "-v"){ |v|
                @version = Gem::Version.new(v)
            }
            opt.on("--all", _("Setup all active apps")){ |all|
                @all = true
            }
        end

        set_execution_block do |apps|
            require 'spiderfw'
            apps = Spider.apps.keys if @all
            if (apps.length > 1) && (@to || @from || @version)
                raise "Can't use --from, --to or --version with multiple apps"
            end
            if apps.length == 0
                require 'lib/spiderfw/setup/spider_setup_wizard'
                wizard = Spider::SpiderSetupWizard.new
                wizard.implementation(Spider::ConsoleWizard)
                wizard.run
                
            end
            apps.each do |name|
                Spider.load_app(name) unless Spider.apps[name]
                app = Spider.apps[name]
                path = app.setup_path
                current = @from || app.installed_version
                new_version = @to || app.version
                next unless File.exist?(path)
                tasks = []
                if @version
                    tasks = ["#{@version}.rb"]
                else
                    tasks = Dir.entries(path).reject{ |p| p[0].chr == '.'}.sort{ |a, b| 
                        va = Gem::Version.new(File.basename(a, '.rb'))
                        vb = Gem::Version.new(File.basename(b, '.rb'))
                        va <=> vb
                    }
                    if @from || @to
                        tasks.reject!{ |t|
                            v = Gem::Version.new(File.basename(t, '.rb'))
                            true if @from && v < @from
                            true if @to && v > @to
                            false
                        }
                    end
                end
                done_tasks = []
                Spider::Model::Managed.no_set_dates = true
                tasks.each do |task|
                    Spider.logger.info("Running setup task #{path+'/'+task}")
                    t = Spider::SetupTask.load("#{path}/#{task}")
                    t.app = app
                    begin
                        done_tasks << t
                        t.do_up
                    rescue => exc
                        done_tasks.each{ |dt| dt.do_down } # FIXME: rescue and log errors in down
                        raise
                    end
                end
                Spider::Model::Managed.no_set_dates = false
                app.installed_version = app.version
            end 
        end


    end

end