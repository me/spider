class AppCommand < CmdParse::Command


    def initialize
        super('app', true, true )
        @short_desc = _("Manage apps")
        
        
        self.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--proxy [SERVER]", _("Proxy server to use (http://user:pass@host:port)"), "-p"){ |p|
                ENV['http_proxy'] = p
            }
            opt.on("--server [SERVER]", _("App server"), "-s") { |s|
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
                require 'spiderfw/home'
                home = Spider::Home.new(Dir.pwd)
                installed = {}
                Spider.init_base
                active = Spider.config.get('apps')
                Spider.home.apps.each do |app, info|
                    installed[app] = {
                        :active => active.include?(app)
                    }
                    if spec = info[:spec]
                        installed[app].merge!({
                            :version => spec.version
                        })                        
                    end
                end
            end
            if @remote
                require 'spiderfw/setup/app_server_client'
                unless @server_url
                    require 'spiderfw/spider'
                    Spider.init_base
                    @server_url = Spider.config.get('app_server.url')
                end
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
                puts "*** "+_('INSTALLED APPS')+" ***"
                puts  
                installed.keys.sort.each do |app|                  
                    details = installed[app]
                    str = app
                    str += " #{details[:version]}" if details[:version]
                    str += " (#{_('not loaded')})" unless details[:active]
                    puts str
                end
            end
            if @remote
                puts
                puts "*** "+_('REMOTE APPS')+" ***"
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
            opt.on("--git", _("Use git for installing apps"), "-g"){ |r| @git = true }
            opt.on("--no-dependencies", _("Don't install other apps this one depends on"), "-d"){ |d| 
                @no_deps = true 
            }
            opt.on("--no-gems", _("Don't install ruby gems this app depends on"), "-g"){ |g| @no_gems = true }
            opt.on("--optional", _("Install optional app dependencies"), "-o"){ |o| @optional = true }
            opt.on("--no-optional-gems", _("Don't install optional gem dependencies"), "-G"){ |g| 
                @no_optional_gems = true
            }
            opt.on("--ssh-user [USERNAME]", _("SSH user")){ |s| @ssh_user = s }
            opt.on("--no-activate", _("Don't activate installed apps")){ |s| @no_activate = true }
        end
        install.set_execution_block do |args|
            unless File.exist?('init.rb') && File.directory?('apps')
                puts _("Please execute this command from the home folder")
                exit
            end
            require 'spiderfw/setup/app_manager'
            options = {
                :git => @git, :all => @all, :no_deps => @no_deps, :optional => @optional, 
                :no_gems => @no_gems, :no_optional_gems => @no_optional_gems, :no_activate => @no_activate
            }
            options[:url] = @server_url if @server_url
            Spider::AppManager.install_apps(args, options)
        end
        self.add_command(install)
        
        activate = CmdParse::Command.new('activate', false )
        activate.short_desc = _("Activate an app")
        activate.set_execution_block do |args|
            apps = args
            require 'spiderfw/spider'
            apps = Spider.get_app_deps(apps)
            Spider.activate_apps(apps)
        end
        self.add_command(activate)
        
        update = CmdParse::Command.new( 'update', false )
        update.short_desc = _("Update an app")
        update.options = CmdParse::OptionParserWrapper.new do |opt|
            opt.on("--all", _("Update all apps"), "-a"){ |a| @all = true }
            opt.on("--no-git", _("Don't use git for updating apps"), "-g"){ |r| @no_git = true }
            opt.on("--no-dependencies", _("Don't install other apps this one depends on"), "-d"){ |d| 
                @no_deps = true 
            }
            opt.on("--no-gems", _("Don't install ruby gems this app depends on"), "-g"){ |g| @no_gems = true }
            opt.on("--no-optional", _("Don't install optional app dependencies"), "-D"){ |o| @no_optional = true }
            opt.on("--no-optional-gems", _("Don't install optional gem dependencies"), "-G"){ |g| 
                @no_optional_gems = true
            }
        end
        update.set_execution_block do |args|
            unless File.exist?('init.rb') && File.directory?('apps')
                puts _("Please execute this command from the home folder")
                exit
            end
            require 'spiderfw/setup/app_manager'
            options = {
                :no_git => @no_git, :all => @all, :no_deps => @no_deps, :no_optional => @no_optional, 
                :no_gems => @no_gems, :no_optional_gems => @no_optional_gems
            }
            options[:url] = @server_url if @server_url
            Spider::AppManager.update_apps(args, options)
        end
        self.add_command(update)
        
    end
end