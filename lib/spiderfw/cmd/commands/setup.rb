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
            require 'spiderfw/spider'
            Spider.init_base
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
                require 'spiderfw/setup/app_manager'
                Spider::AppManager.new.setup(name)
            end
        end


    end

end