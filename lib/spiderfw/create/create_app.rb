require 'fileutils'
require 'erb'

module Spider
    
    module CreateApp
        
        
        def self.create(name, path, module_name=nil)
            name_parts = name.split('/')
            app_name = name_parts[-1]
            app_path = name
            module_full_name ||= Inflector.camelize(name)
            modules = module_full_name.split('::')
            module_name = modules[-1]
            b = binding
            dest_folder = path+'/'+name
            raise RuntimeError, "Folder #{path} does not exist" unless File.exist?(path)
            raise RuntimeError, "Folder #{dest_folder} already exists" if File.exist?(dest_folder)
            #FileUtils.mkdir_p(File.expand_path(dest_path+'/..'))
            source_folder = $SPIDER_PATH+'/blueprints/app'
            FileUtils.mkdir_p(dest_folder)
            replacements = {
                '__APP__' => app_name,
                '__MODULE__' => modules[modules.length-1]
            }
            Find.find(source_folder) do |source_path|
                next if source_path == source_folder
                rel_path = source_path[source_folder.length+1..-1]
                dest_path = rel_path
                replacements.each do |search, replace|
                    dest_path.gsub!(search, replace)
                end
                if (File.directory?(source_path))
                    FileUtils.mkdir(dest_folder+'/'+dest_path)
                else
                    dst = File.new(dest_folder+'/'+dest_path, 'w')
                    res = ERB.new(IO.read(source_path)).result(b)
                    dst.puts(res)
                    dst.close
                end
            end
        end
        
    end
    
end