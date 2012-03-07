require 'tempfile'
require 'fileutils'

module Spider

    class AppManager

        def initialize(options={})
            @options = options
        end
        
        def self.installed?(app)
            require 'spiderfw/home'
            Spider.init_base
            @home_apps ||= Spider.home.apps
            @home_apps[app]
        end
        
        def self.git_available?
            begin
                require 'git'
                return true
            rescue LoadError => exc
                return false
            end
        end
        
        def self.tmp_path(home_path)
            tmp_path = File.join(home_path, 'tmp', 'app_update')
        end

        def tmp_path
            self.class.tmp_path(@home_path)
        end
        
        def self.resolve(apps, options={})
            specs = []
            url = options[:url]
            unless url
                require 'spiderfw/spider'
                Spider.init_base
                url = Spider.config.get('app_server.url')
            end
            install = []
            update = []
            res = {:install => install, :update => update}
            return res if apps.empty?
            require 'spiderfw/setup/app_server_client'
            client = Spider::AppServerClient.new(url)
            if options[:branch]
                apps = apps.map{ |a| "#{a}@#{options[:branch]}"}
            end
            if options[:no_deps]
                specs = client.get_specs(apps)
            else
                specs = client.get_deps(apps, :no_optional => !options[:optional])
            end
            specs.each do |spec|
                if prev = installed?(spec.app_id)
                    if (options[:refresh] && options[:refresh].include?(spec.app_id) ) || (prev[:spec] && prev[:spec].version < spec.version)
                        update << spec
                    end
                else
                    install << spec
                end
            end
            return res
        end
        
        def self.get_apps(apps, options={})
            specs = resolve(apps, options)
            manager = self.new
            manager.install(specs, options)
            return specs
        end

        
        def install(specs, options)
            options[:home_path] ||= Dir.pwd
            @home_path = options[:home_path]
            all_specs = specs[:install] + specs[:update]

            pre_run(all_specs, options)
            specs[:install].each do |spec|
                do_install(spec, options)
            end
            pre_update(specs[:update], options)
            begin
                specs[:update].each do |spec|
                    do_update(spec, options)
                end
                post_update(specs[:update], options)
            rescue
                rollback_update unless options[:no_rollback]
                raise
            end
            unless options[:no_activate]
                require 'spiderfw/spider'
                specs_hash = {}
                all_specs.each{ |s| specs_hash[s.app_id] = s }
                Spider.activate_apps(specs[:install].map{ |s| s.app_id }, specs_hash)
            end
            Spider.output _("Install done.")
        end

        def do_install(spec, options)
            app_path = File.join(@home_path, "apps/#{spec.app_id}")
            raise "App #{spec.app_id} is already installed" if File.exists?(app_path)
            use_git = false
            if spec.git_repo && options[:use_git]
                use_git = true
            end
            if use_git && !self.class.git_available?
                Spider.output _("Can't install app #{spec.id} via git, since git gem is not available") % spec.app_id, :ERROR
            end
            if use_git
                git_install(spec, options)
            else
                pack_install(spec, options)
            end
        end

        
        def do_update(spec, options)
            use_git = false
            if spec.git_repo && !options[:no_git]
                app_path = File.join(@home_path, "apps/#{spec.app_id}")
                use_git = true if File.exists?(File.join(app_path, '.git'))
            end
            if use_git && !self.class.git_available?
                Spider.output _("Can't update app #{spec.id} via git, since git gem is not available") % spec.app_id, :ERROR
            end
            if use_git
                git_update(spec, options)
            else
                pack_update(spec, options)
            end
        end
        
        def pre_run(specs, options={})
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
        
        def self.post_run(specs, options={})
            #require 'bundler'
            #Bundler::Installer.install(options[:home_path], Bundler.definitions, {})
        end
        
        def pre_update(specs, options={})
            tmp_path = File.join(self.tmp_path, "update-#{DateTime.now.strftime('%Y%m%d-%H%M')}")
            @backup_path = tmp_path
            FileUtils.mkdir_p(tmp_path)
            @previous_apps = {}
            specs.each do |spec|
                app_path = File.join(@home_path, 'apps', spec.id)
                FileUtils.cp_r(app_path, tmp_path)
                @previous_apps[spec.app_id] = App::AppSpec.load(File.join(app_path, "#{spec.id}.appspec"))
            end
        end
        
        def post_update(specs, options)
            return if specs.empty?
            require 'spiderfw/home'
            Spider.init_base
            @done_tasks = {}
            specs.each do |spec|
                prev_spec = @previous_apps[spec.app_id]
                prev_v = prev_spec.version if prev_spec
                @done_tasks[spec.app_id] = setup(spec.app_id, prev_v, spec.version)
            end
            Spider.output _("Doing cleanup...")
            @done_tasks.each do |app, tasks|
                next unless tasks
                tasks.each do |task|
                    begin
                        task.do_cleanup
                    rescue => exc
                        Spider.logger.error("Cleanup failed for #{app}:")
                        Spider.logger.error(exc)
                    end
                end
            end
            if @options[:interactive]
                puts "\n\n"
                @done_tasks.each do |app, tasks|
                    next unless tasks
                    tasks.each do |task|
                        task.print_release_notes 
                    end
                end
            end
            if options[:clear_cache]
                Spider.output _("Clearing cache...")
                Spider::Template.cache.clear!
                Spider::Layout.clear_compiled_folder!
            end
            if options[:restart]
                Spider.output _("Restarting server...")
                Spider.restart!
            end
            Spider.output _("Post-update done")
        end
        
        def rollback_update
            Dir.new(@backup_path).each do |app|
                next if app[0].chr == '.'
                installed = File.join(@home_path, 'apps', app)
                FileUtils.rm_rf(installed) if File.exists?(installed)
                FileUtils.mv(File.join(@backup_path, app), installed)
            end
            if @done_tasks
                @done_tasks.each do |app, tasks|
                    next unless tasks
                    tasks.reverse.each do |task|
                        task.down
                    end
                end
            end
        end
        
        
        def git_install(spec, options={})
             require 'git'
             if ::File.exist?("apps/#{spec.id}")
                 Spider.output _("%s already installed, skipping") % spec.id
                 return
             end
             repo = nil
             if ::File.directory?(File.join(@home_path, '.git'))
                repo = Git.open(@home_path)
             end
             repo_url = options[:rw] ? spec.git_repo_rw : spec.git_repo
             Spider.output _("Fetching %s from %s") % [spec.app_id, repo_url]

             if options[:ssh_user] && repo_url =~ /ssh:\/\/([^@]+@)?(.+)/
                 repo_url = "ssh://#{options[:ssh_user]}@#{$2}"
             end

             ENV['GIT_WORK_TREE'] = nil
             if repo
                 Dir.chdir(@home_path) do   
                     `git submodule add #{repo_url} apps/#{spec.id}`
                     `git submodule init`
                     `git submodule update`
                     repo.add(['.gitmodules', "apps/#{spec.id}"])
                     begin
                        repo.commit(_("Added app %s") % spec.id) 
                    rescue Git::GitExecuteError => exc
                        # If no changes added, it means the app was deleted and then reinstalled, 
                        # no need to raise an exception
                        raise unless exc.message =~ /no changes added/
                    end
                 end
            else
                Dir.chdir(File.join(@home_path, 'apps')) do
                    Git.clone(repo_url, spec.id) 
                end
            end
            app_path = File.join(@home_path, "apps", spec.id)
            if spec.branch != 'master'
                reset_git_env
                Dir.chdir(app_path) do
                    `git checkout #{spec.branch}`
                end
            end
         end

         def pack_install(spec, options={})
             require 'rubygems/package'
             client = AppServerClient.new(spec.app_server)
             print _("Fetching %s from server... ") % spec.app_id
             tmp_path = client.fetch_app(spec.app_id, spec.branch)
             Spider.output _("Fetched.")
             dest = File.join(@home_path, "apps/#{spec.app_id}")
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
             if File.directory?(File.join(@home_path, '.git'))
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
        
        def git_update(spec, options={})
            require 'git'
            home_repo = nil
            if ::File.directory?(File.join(@home_path, '.git'))
                home_repo = Git.open(@home_path)
            end
            app_path = File.join(@home_path, "apps", spec.id)
            app_repo = Git.open(app_path)
            Spider.output _("Updating %s from %s") % [spec.app_id, spec.git_repo]
            Dir.chdir(app_path) do
                response = `git status`
                unless response =~ /working directory clean/
                    Spider.output(_("You have local modifications in the #{spec.id} app"), :ERROR)
                    Spider.output(_("Commit them or reset repo to update"), :ERROR)
                    exit
                end
                `git checkout master`
            end
            response = err = nil
            Dir.chdir(app_path) do
                response = `git --git-dir='#{app_path}/.git' pull origin master`
            end
            if response =~ /Aborting/
                Spider.output err, :ERROR
                raise "Unable to update"
            end
            if spec.branch != 'master'
                Dir.chdir(app_path) do
                    `git checkout #{spec.branch}`
                end
            end
            # response = err = nil
            # Dir.chdir(app_path) do
            #     response = `git --git-dir='#{app_path}/.git' pull origin #{options[:branch]}`
            # end
            #  app_repo.branch(options[:branch]).checkout
            # require 'ruby-debug'
            # if response =~ /Aborting/
            #     Spider.output err, :ERROR
            #     raise "Unable to update"
            # end
            # Dir.chdir(app_path) do
            #     app_repo.reset('HEAD', :hard => true)
            #     app_repo.branch(options[:branch]).checkout
            # end
            
            if home_repo
                home_repo.add("apps/#{spec.id}")
                begin
                    home_repo.commit(_("Updated app %s") % spec.id) 
                rescue => exc
                    raise unless exc.message =~ /no changes added to commit/
                end
            end
        end
        
        def pack_update(spec, options={})
            require 'fileutils'
            require 'date'
            require 'time'
            app_path = File.join(@home_path, "apps/#{spec.id}")
            tmp_path = self.tmp_path
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
                pack_install(spec, options)
                FileUtils.rm_rf(tmp_app_path)
            rescue => exc
                Spider.output _("Update of %s failed") % spec.id, :ERROR
                Spider.output exc, :ERROR
                FileUtils.rm_rf(app_path)
                FileUtils.mv(tmp_app_path, app_path)
                raise
            end
        end
        
        def setup(name, from=nil, to=nil)
            require 'spiderfw/setup/setup_task'
            Spider.init
            Spider.load_app(name) unless Spider.apps[name]
            app = Spider.apps_by_short_name[name]
            path = app.setup_path
            unless to
                version = from
                from = nil
            end
            current = from || app.installed_version
            new_version = to || app.version
            return unless File.exist?(path)
            tasks = []
            if version
                tasks = ["#{@version}.rb"]
            else
                tasks = Dir.entries(path).reject{ |p| !File.file?(File.join(path, p)) || p[0].chr == '.'}.sort{ |a, b| 
                    va = Gem::Version.new(File.basename(a, '.rb'))
                    vb = Gem::Version.new(File.basename(b, '.rb'))
                    va <=> vb
                }
                if from || to
                    tasks.reject!{ |t|
                        v = Gem::Version.new(File.basename(t, '.rb'))
                        if from && v <= from
                            true
                        elsif to && v > to
                            true
                        else
                            false
                        end
                    }
                end
            end
            done_tasks = []

            
            tasks.each do |task|
                Spider.output _("Running setup task #{path+'/'+task}...")
                t = Spider::SetupTask.load("#{path}/#{task}")
                t.app = app
                raise "Can't run interactive task" if t.interactive? && !@options[:interactive]
                begin
                    done_tasks << t
                    t.do_sync
                    t.do_up
                    Spider.output _("Setup task done")
                rescue => exc
                    Spider.output exc, :ERROR
                    done_tasks.reverse.each do |dt| 
                        begin
                            dt.do_down 
                        rescue => exc
                            Spider.output("Unable to do down on #{dt}!", :ERROR)
                            Spider.output(exc, :ERROR)
                        end
                    end
                    raise
                end
            end
            app.installed_version = app.version
            done_tasks
        end


        private

        def reset_git_env
            ENV['GIT_WORK_TREE'] = nil
            ENV["GIT_INDEX_FILE"] = nil
            ENV["GIT_WORK_TREE"] = nil
            ENV["GIT_DIR"] = nil
        end


    end

end
