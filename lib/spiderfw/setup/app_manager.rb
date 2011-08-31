require 'tempfile'
require 'fileutils'

module Spider

    module AppManager
        
        def self.install_or_update(apps, options={})
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
            to_inst = apps.select{ |a| !installed[a] }
            to_upd = apps.select{ |a| installed[a] }
            install_apps(to_inst, options)
            update_apps(to_upd, options)
            return {:installed => to_inst, :updated => to_upd}
        end
        
        def self.install_apps(apps, options={})
            return if apps.empty?
            require 'spiderfw/setup/app_server_client'
            use_git = false
            if options[:git]
                begin
                    require 'git'
                    use_git = true
                rescue LoadError => exc
                    Spider.output exc.message, :ERROR
                    Spider.output "git gem not available; install git gem for Git support", :ERROR
                end
            end
            
            existent = []
            apps.each do |app|
                if File.exist?("apps/#{app}")
                    Spider.output _("%s already exists, skipping") % app
                    existent << app
                end
            end
            require 'spiderfw/setup/app_manager'
            specs = []
            url = options[:url]
            unless url
                require 'spiderfw/spider'
                Spider.init_base
                url = Spider.config.get('app_server.url')
            end
            client = Spider::AppServerClient.new(url)
            if options[:no_deps]
                specs = client.get_specs(apps)
            else
                specs = client.get_deps(apps, :no_optional => !options[:optional])
            end
            deps = specs.map{ |s| s.app_id }
            unless (deps - apps).empty?
                Spider.output _("The following apps will be installed as a dependency:")
                Spider.output((deps - apps).inspect)
            end
            i_options = {
                :use_git => use_git, 
                :no_gems => options[:no_gems],
                :no_optional_gems => options[:no_optional_gems]
            }
            i_options[:ssh_user] = options[:ssh_user] if options[:ssh_user]
            inst_specs = specs.reject{ |s| existent.include? s.app_id }
            Spider::AppManager.install(inst_specs, Dir.pwd, i_options)
            unless options[:no_activate]
                require 'spiderfw/spider'
                specs_hash = {}
                specs.each{ |s| specs_hash[s.app_id] = s }
                Spider.activate_apps(deps, specs_hash)
            end
            
        end
        
        def self.update_apps(apps, options={})
            require 'spiderfw/spider'
            require 'spiderfw/setup/app_server_client'
            Spider.init_base
            url = options[:url] || Spider.conf.get('app_server.url')
            if options[:all]
                require 'spiderfw/home'
                home = Spider::Home.new(Dir.pwd)
                apps = home.list_apps
            end
            if apps.empty?
                Spider.output _("No app to update")
                exit
            end
            specs = []
            client = Spider::AppServerClient.new(url)
            if options[:no_deps]
                specs = client.get_specs(apps)
            else
                specs = client.get_deps(apps, :no_optional => options[:no_optional])
            end
            deps = specs.map{ |s| s.app_id }
            unless (deps - apps).empty?
                Spider.output _("The following apps will be updated as a dependency:")
                Spider.output((deps - apps).inspect)
            end
            Spider::AppManager.update(specs, Dir.pwd, {
                :use_git => !options[:no_git], 
                :no_gems => options[:no_gems],
                :no_optional_gems => options[:no_optional_gems]
            })
        end

        def self.install(specs, home_path, options)
            options[:home_path] = home_path
            specs = [specs] if specs && !specs.is_a?(Array)
            specs ||= []
            pre_setup(specs, options)
            specs.each do |spec|
                app_path = File.join(home_path, "apps/#{spec.app_id}")
                if File.directory?(app_path)
                    if File.directory?(File.join(app_path, '.git'))
                        git_update(spec, home_path, options)
                    else
                        pack_update(spec, home_path, options)
                    end
                else
                    if spec.git_repo && options[:use_git]
                        git_install(spec, home_path, options)
                    else
                        pack_install(spec, home_path, options)
                    end
                end
            end
            post_setup(specs, options)
        end

        def self.git_install(spec, home_path, options={})
            require 'git'
            if ::File.exist?("apps/#{spec.id}")
                Spider.output _("%s already installed, skipping") % spec.id
                return
            end
            repo = Git.open(home_path)
            repo_url = spec.git_repo_rw || spec.git_repo
            Spider.output _("Fetching %s from %s") % [spec.app_id, repo_url]
            
            if options[:ssh_user] && repo_url =~ /ssh:\/\/([^@]+@)?(.+)/
                repo_url = "ssh://#{options[:ssh_user]}@#{$2}"
            end
            
            ENV['GIT_WORK_TREE'] = nil
            Dir.chdir(home_path) do
                `git submodule add #{repo_url} apps/#{spec.id}`
                `git submodule init`
                `git submodule update`
            end
            repo.add(['.gitmodules', "apps/#{spec.id}"])
            repo.commit(_("Added app %s") % spec.id) 
        end

        def self.pack_install(spec, home_path, options={})
            require 'rubygems/package'
            client = AppServerClient.new(spec.app_server)
            print _("Fetching %s from server... ") % spec.app_id
            tmp_path = client.fetch_app(spec.app_id)
            Spider.output _("Fetched.")
            dest = File.join(home_path, "apps/#{spec.app_id}")
            FileUtils.mkdir_p(dest)
            open tmp_path, Gem.binary_mode do |io|
                Gem::Package::TarReader.new(io) do |reader|
                    reader.each do |entry|
                        dest_path = File.join(dest, entry.full_name)
                        if entry.directory?
                            FileUtils.mkdir(dest_path)
                        elsif entry.file?
                            File.open(dest_path, 'w') do |f|
                                f << entry.read
                            end
                        end
                    end
                end
            end
            if File.directory?(File.join(home_path, '.git'))
                begin
                    require 'git'
                rescue LoadError
                end
                begin
                    repo = Git.open(home_path)
                    repo.add("apps/#{spec.id}")
                    repo.commit(_("Added app %s") % spec.id)
                rescue => exc
                end
            end
        end
        
        def self.pre_setup(specs, options={})
            require 'rubygems'
            require 'rubygems/command.rb'
            require 'rubygems/dependency_installer.rb'
            unless options[:no_gems]
               gems = specs.map{ |s| s.gems_list }
               gems = gems.flatten.uniq
               gems.reject!{ |g| Spider.gem_available?(g) }
               unless gems.empty?
                   Spider.output _("Installing the following needed gems:")
                   Spider.output gems.inspect
                   inst = Gem::DependencyInstaller.new
                    gems.each do |g|
                        inst.install g
                    end
                end
                unless options[:no_optional_gems]
                    gems = specs.map{ |s| s.gems_optional_list }
                    gems = gems.flatten.uniq
                    gems.reject!{ |g| Spider.gem_available?(g) }
                    unless gems.empty?
                        Spider.output _("Installing the following optional gems:")
                        Spider.output gems.inspect
                        inst = Gem::DependencyInstaller.new
                        gems.each do |g|
                            begin
                                inst.install g
                            rescue => exc
                                Spider.output _("Unable to install optional gem %s:") % g
                                Spider.output exc, :ERROR
                            end
                        end
                    end
               end
                # unless Spider.gem_available?('bundler')
                #     puts _("Installing bundler gem")
                #     inst = Gem::DependencyInstaller.new
                #     inst.install 'bundler'
                # end
            end
        end
        
        def self.pre_update(specs, options={})
        end
        
        def self.post_setup(specs, options={})
            #require 'bundler'
            #Bundler::Installer.install(options[:home_path], Bundler.definitions, {})
        end
        
        def self.update(specs, home_path, options)
            specs = [specs] unless specs.is_a?(Array)
            pre_setup(specs, options)
            pre_update(specs, options)
            git_available = nil
            specs.each do |spec|
                use_git = false
                if spec.git_repo && options[:use_git]
                    app_path = File.join(home_path, "apps/#{spec.id}")
                    use_git = true if File.directory?(File.join(app_path, '.git'))
                end
                use_git = false if git_available == false
                if use_git && git_available.nil?
                    begin
                        require 'git'
                        use_git = true
                    rescue LoadError => exc
                        Spider.output "git gem not available; install git gem for Git support"
                        use_git = false
                    end
                end
                if use_git
                    git_update(spec, home_path, options)
                else
                    pack_update(spec, home_path, options)
                end
            end
        end
        
        def self.git_update(spec, home_path, options={})
            require 'git'
            home_repo = Git.open(home_path)
            app_path = File.join(home_path, "apps/#{spec.id}")
            app_repo = Git.open(app_path)
            Spider.output _("Updating %s from %s") % [spec.app_id, spec.git_repo]
            Dir.chdir(app_path) do
                app_repo.branch('master').checkout
            end
            response = err = nil
            Dir.chdir(app_path) do
                `git --git-dir='#{app_path}/.git' pull origin master`
            end
            if response =~ /Aborting/
                Spider.output err, :ERROR
                return
            end
            Dir.chdir(app_path) do
                app_repo.reset('HEAD', :hard => true)
                app_repo.branch('master').checkout
            end
            
            home_repo.add("apps/#{spec.id}")
            home_repo.commit(_("Updated app %s") % spec.id) 
        end
        
        def self.pack_update(spec, home_path, options={})
            require 'fileutils'
            require 'date'
            require 'time'
            app_path = File.join(home_path, "apps/#{spec.id}")
            tmp_path = File.join(home_path, 'tmp')
            FileUtils.mkdir_p(tmp_path)
            tmp_app_path = File.join(tmp_path, "#{spec.id}-update-#{DateTime.now.strftime('%Y%m%d-%H%M')}")
            begin
                FileUtils.mv(app_path, tmp_app_path)
            rescue Errno::EACCES
                if RUBY_PLATFORM =~ /win32|mingw/
                    Spider.output(
                        _("Can't update #{spec.id} app: ensure you have no files or folders of this app open"), 
                        :ERROR
                    )
                else
                    Spider.output exc, :ERROR
                end
                exit
            end
            begin
                pack_install(spec, home_path)
                FileUtils.rm_rf(tmp_app_path)
            rescue => exc
                Spider.output _("Update of %s failed") % spec.id, :ERROR
                Spider.output exc, :ERROR
                FileUtils.rm_rf(app_path)
                FileUtils.mv(tmp_app_path, app_path)
            end
        end
        

    end

end