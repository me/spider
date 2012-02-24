module Spider::CommandLine

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
                opt.on("--no-cleanup", _("Don't cleanup"), "-C"){ |no_cleanup| @no_cleanup = true }
            end

            set_execution_block do |apps|
                $SPIDER_INTERACTIVE = true
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
                tasks = []
                apps.each do |name|
                    require 'spiderfw/setup/app_manager'
                    tasks += Spider::AppManager.new(:interactive => true).setup(name, @from, @to)
                end
                unless @no_cleanup
                    tasks.each do |t|
                        begin
                            t.do_cleanup
                        rescue => exc
                            Spider.logger.error(exc)
                        end
                    end
                end
            end


        end

    end

end