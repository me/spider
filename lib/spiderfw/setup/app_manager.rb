require 'tempfile'
require 'fileutils'

module Spider

    module AppManager

        def self.install(specs, home_path, options)
            options[:use_git] = true unless options[:use_git] == false
            options[:home_path] = home_path
            specs = [specs] unless specs.is_a?(Array)
            pre_setup(specs, options)
            specs.each do |spec|
                if spec.git_repo && options[:use_git]
                    git_install(spec, home_path, options)
                else
                    pack_install(spec, home_path, options)
                end
            end
            post_setup(specs, options)
        end

        def self.git_install(spec, home_path, options={})
            require 'grit'
            if ::File.exist?("apps/#{spec.id}")
                puts _("%s already installed, skipping") % spec.id
                return
            end
            repo = Grit::Repo.new(home_path)
            puts _("Fetching %s from %s") % [spec.app_id, spec.git_repo]
            repo_url = spec.git_repo
            if options[:ssh_user] && repo_url =~ /ssh:\/\/([^@]+@)?(.+)/
                repo_url = "ssh://#{options[:ssh_user]}@#{$2}"
            end
            `#{Grit::Git.git_binary} submodule add #{repo_url} apps/#{spec.id}`
            repo.git.submodule({}, "init")
            repo.git.submodule({}, "update")
            repo.add('.gitmodules', "apps/#{spec.id}")
            repo.commit_index(_("Added app %s") % spec.id) 
        end

        def self.pack_install(spec, home_path, options={})
            require 'rubygems/package'
            client = AppServerClient.new(spec.app_server)
            print _("Fetching %s from server... ") % spec.app_id
            tmp_path = client.fetch_app(spec.app_id)
            puts _("Fetched.")
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

        end
        
        def self.pre_setup(specs, options={})
            require 'rubygems'
            require 'rubygems/command.rb'
            require 'rubygems/dependency_installer.rb'
            unless options[:no_gems]
                unless Gem.available?('bundler')
                    puts _("Installing bundler gem")
                    inst = Gem::DependencyInstaller.new
                    inst.install 'bundler'
                end
            end
        end
        
        def self.post_setup(specs, options={})
            require 'bundler'
            Bundler::Installer.install(options[:home_path], Bundler.definitions, {})
        end
        
        def self.update(specs, home_path, options)
            options[:use_git] = true unless options[:use_git] == false
            specs = [specs] unless specs.is_a?(Array)
            pre_setup(specs, options)
            specs.each do |spec|
                if spec.git_repo && options[:use_git]
                    git_update(spec, home_path, options)
                else
                    pack_update(spec, home_path, options)
                end
            end
        end
        
        def self.git_update(spec, home_path, options={})
            require 'grit'
            home_repo = Grit::Repo.new(home_path)
            app_path = File.join(home_path, "apps/#{spec.id}")
            app_repo = Grit::Repo.new(app_path)
            puts _("Updating %s from %s") % [spec.app_id, spec.git_repo]
            Dir.chdir(app_path) do
                app_repo.git.checkout({}, "master")
            end
            cmd = "#{Grit::Git.git_binary} --git-dir='#{app_path}/.git' pull"
            response = err = nil
            Dir.chdir(app_path) do
                response, err = app_repo.git.wild_sh(cmd)
            end
            if response =~ /Aborting/
                puts err
                return
            end
            Dir.chdir(app_path) do
                app_repo.git.reset({:hard => true}, 'HEAD')
                app_repo.git.checkout
            end
            
            home_repo.add("apps/#{spec.id}")
            home_repo.commit_index(_("Updated app %s") % spec.id) 
        end
        
        def self.pack_update(spec, home_path, options={})
            require 'fileutils'
            require 'date'
            require 'time'
            app_path = File.join(home_path, "apps/#{spec.id}")
            tmp_path = File.join(home_path, 'tmp')
            FileUtils.mkdir_p(tmp_path)
            tmp_app_path = File.join(tmp_path, "#{spec.id}-update-#{DateTime.now}")
            FileUtils.mv(app_path, tmp_app_path)
            begin
                pack_install(spec, home_path)
                FileUtils.rmdir(tmp_app_path)
            rescue
                puts _("Update of %s failed" % spec.id)
                FileUtils.mv(tmp_app_path, app_path)
            end
        end
        
        

    end

end