class AppCommand < CmdParse::Command


    def initialize
        super('app', true, true )
        @short_desc = _("Manage apps")
        
        @server_url = 'http://www.soluzionipa.it/euroservizi/spider/app_server'
        
        self.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--proxy", _("Proxy server to use (http://user:pass@host:port)"), "-p"){ |p|
                ENV['http_proxy'] = p
            }
            opt.on("--server", _("App server"), "-s") { |s|
                @server_url = s
            }
        end
  
        @installed = true
        
        list = CmdParse::Command.new( 'list', false )
        list.short_desc = _("List installed and available apps")
        list.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--installed", _("List installed apps (the default)")) { |installed|
                @remote = false
            }
            opt.on("--remote", _("List only remote apps"), "-r"){ |r|
                @installed = false
                @remote = true
            }
            opt.on("--all", _("List both local and remote apps"), "-a"){ |a|
                @installed = true
                @remote = true
                @all = true
            }
            opt.on("--core", _("Include apps that come with spider"), "-c"){ |c|
                @core = true
            }
        end
        list.set_execution_block do |args|
            if @installed
                require 'spiderfw'
                installed = {}
                Spider.home.list_apps.each do |app|
                    installed[app] = {
                        :active => Spider.apps_by_path[app] ? true : false
                    }
                    if appspec = Dir.glob("#{Spider.paths[:apps]}/#{app}/*.appspec")[0]
                        info = Spider::App::AppSpec.load(appspec)
                        installed[app].merge!({
                            :version => info.version
                        })
                    end
                end
            end
            if @remote
                require 'spiderfw/setup/app_server_client'
                client = Spider::AppServerClient.new(@server_url)
                remote = {}
                client.specs.each do |app|
                    remote[app.app_id] = {
                        :version => app.version
                    }
                    if installed && installed[app] && installed[app][:version]
                        v = Gem::Version.new(installed[app][:version])
                        if v < app.version
                            installed[app][:available] = app.version
                        end
                    end
                end
            end
            if @installed
                puts
                puts "*** INSTALLED APPS ***"
                puts  
                installed.keys.sort.each do |app|                  
                    details = installed[app]
                    str = app
                    str += " #{details[:version]}" if details[:version]
                    str += " (#{_('active')})" if details[:active]
                    puts str
                end
            end
            if @remote
                puts
                puts "*** REMOTE APPS ***"
                puts
                remote.keys.sort.each do |app|
                    details = remote[app]
                    str = app
                    str += " #{details[:version]}" if details[:version]
                    puts str
                end
            end
            puts
        end
        self.add_command( list )
        
        
        install = CmdParse::Command.new( 'install', false )
        install.short_desc = _("Install an app")
        install.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--no-git", _("Don't use git for installing apps"), "-g"){ |r| @no_git = true }
            opt.on("--no-dependencies", _("Don't install other apps this one depends on"), "-d"){ |d| 
                @no_deps = true 
            }
            opt.on("--no-gems", _("Don't install ruby gems this app depends on"), "-g"){ |g| @no_gems = true }
            opt.on("--no-optional", _("Don't install optional app dependencies"), "-D"){ |o| @no_optional = true }
            opt.on("--no-optional-gems", _("Don't install optional gem dependencies"), "-G"){ |g| 
                @no_optional_gems = true
            }
        end
        install.set_execution_block do |args|
            unless File.exist?('init.rb') && File.directory?('apps')
                puts _("Please execute this command from the home folder")
                exit
            end
            require 'spiderfw/setup/app_server_client'
            use_git = false
            unless @no_git
                begin
                    require 'grit'
                    use_git = true
                rescue
                    puts "Grit not available; install Grit for Git support"
                end
            end
            apps = args
            existent = []
            apps.each do |app|
                if File.exist?("apps/#{app}")
                    puts _("%s already exists, skipping") % app
                    existent << app
                end
            end
            apps -= existent
            require 'spiderfw/setup/app_manager'
            specs = []
            client = Spider::AppServerClient.new(@server_url)
            if @no_deps
                specs = client.get_specs(apps)
            else
                specs = client.get_deps(apps, :no_optional => @no_optional)
            end
            deps = specs.map{ |s| s.app_id }
            unless (deps - apps).empty?
                puts _("The following apps will be installed as a dependency:")
                puts (deps - apps).inspect
            end
            Spider::AppManager.install(specs, Dir.pwd, {
                :use_git => use_git, 
                :no_gems => @no_gems,
                :no_optional_gems => @no_optional_gems
            })
        end
        self.add_command(install)
        
    end
end