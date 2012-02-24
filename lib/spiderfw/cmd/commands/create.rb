require 'spiderfw/spider'
require 'spiderfw/create'

module Spider::CommandLine

    class CreateCommand < CmdParse::Command


        def initialize
            super( 'create', true, true )
            @short_desc = _("Create a working dir for development or installation")
    #        @description = _("")

            app = CmdParse::Command.new( 'app', false )
            app.short_desc = _("Create a new application")
            app.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.on("--path", 
                       _("The path where to create the app (defaults to the app folder under the current path)"),
                       "-p"){ |path|
                    @path = path
                }
                opt.on("--module", _("The module name; by default, the app name will be camelized"), "-m"){ |module_name|
                    @module_name = module_name
                }
            end
            app.set_execution_block do |names|
                @path ||= Dir.pwd+'/apps'
                names.each do |name|
                    Spider::Create.app(name, @path, @module_name)
                    Spider.output "Created app #{name} at #{@path}/#{name}" if ($verbose)
                end
            end
            self.add_command(app, false)
            
            install = CmdParse::Command.new('home', false)
            install.short_desc = _("Create an installation")
            install.options = CmdParse::OptionParserWrapper.new do |opt|
                opt.on("--path [PATH]", 
                       _("The path where to create the installation (defaults to the path)"),
                       "-p"){ |path|
                    @path = path
                }
                opt.on("--no-wizard", _("Don't launch wizard"), "-W"){ |w| @no_wizard = true }
                opt.on("--non-interactive", _("Non interactive"), "-i"){ |i|
                    @no_wizard = true
                }
            end
            install.set_execution_block do |installs|
                @path ||= Dir.pwd
                installs.each do |inst|
                    Spider::Create.home(inst, @path)
                    unless @no_wizard
                        Dir.chdir(inst) do 
                            $SPIDER_RUN_PATH = Dir.pwd
                            $:.push($SPIDER_RUN_PATH)
                            require 'spiderfw/init'
                            require 'lib/spiderfw/setup/spider_setup_wizard'
                            wizard = Spider::SpiderSetupWizard.new
                            wizard.first_run = true
                            wizard.implementation(Spider::ConsoleWizard)
                            wizard.run
                        end
                    end
                end
            end
            self.add_command(install, false)


        end

    end

end