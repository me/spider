require 'fileutils'
require 'find'
require 'erb'
require 'spiderfw/utils/inflector'

module Spider
    
    module Create
        
        
        def self.app(name, path, module_name=nil)
            name_parts = name.split('/')
            app_name = name_parts[-1]
            app_path = name
            module_full_name ||= Spider::Inflector.camelize(name)
            modules = module_full_name.split('::')
            module_name = modules[-1]
            erb_binding = binding
            dest_folder = path+'/'+name
            
            #FileUtils.mkdir_p(File.expand_path(dest_path+'/..'))
            source_folder = $SPIDER_PATH+'/blueprints/app'
            
            replacements = {
                '__APP__' => app_name,
                '__MODULE__' => modules[modules.length-1]
            }
            create(source_folder, dest_folder, replacements, erb_binding)
        end
        
        def self.home(name, path)
            dest_path = path+'/'+name
            source_path = $SPIDER_PATH+'/blueprints/home'
            create(source_path, dest_path)
            
            begin
                require 'git'

                cwd = Dir.getwd
                Dir.chdir(dest_path)
                begin
                    repo = Git.init(dest_path)
                    repo.add(['apps', 'config', 'init.rb', 'public'])
                    repo.add('.gitignore')
                    repo.commit(_("Created repository"))
                rescue => exc
                    Spider.output exc.message, :ERROR
                    Spider.output "Unable to init Git repo, please init manually", :ERROR
                end
                Dir.chdir(cwd)
            rescue LoadError
                Spider.output _("git gem not installed, cannot init repo"), :NOTICE
            end
        end
        
        def self.create(source_path, dest_path, replacements={}, erb_binding=nil)
            raise RuntimeError, "Folder #{source_path} does not exist" unless File.exist?(source_path)
            raise RuntimeError, "Folder #{dest_path} already exists" if File.exist?(dest_path)
            FileUtils.mkdir_p(dest_path)
            erb_binding ||= binding
            if File.exists?("#{source_path}/.dirs")
                File.readlines("#{source_path}/.dirs").each do |dir|
                    dir.strip!
                    replacements.each do |search, replace|
                        dir.gsub!(search, replace)
                    end
                    FileUtils.mkdir_p(dest_path+'/'+dir)
                end
            end
            Find.find(source_path) do |sp|
                next if sp == source_path
                sp =~ /\/([^\/]+)$/
                file_name = $1
                rel_path = sp[source_path.length+1..-1]
                dp = rel_path
                replacements.each do |search, replace|
                    dp.gsub!(search, replace)
                end
                if (File.directory?(sp))
                    FileUtils.mkdir(dest_path+'/'+dp) unless File.directory?(dest_path+'/'+dp)
                else
                    dst = File.new(dest_path+'/'+dp, 'w')
                    res = ERB.new(IO.read(sp)).result(erb_binding)
                    dst.puts(res)
                    dst.close
                end
            end
            Dir.glob("#{dest_path}/**/.dirs").each do |f|
                File.unlink(f)
            end
        end
        
    end
    
end
