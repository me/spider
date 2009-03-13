require 'fileutils'
require 'erb'

module Spider
    
    module Create
        
        
        def self.app(name, path, module_name=nil)
            name_parts = name.split('/')
            app_name = name_parts[-1]
            app_path = name
            module_full_name ||= Inflector.camelize(name)
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
        
        def self.install(name, path)
            dest_path = path+'/'+name
            source_path = $SPIDER_PATH+'/blueprints/install'
            create(source_path, dest_path)
        end
        
        def self.create(source_path, dest_path, replacements={}, erb_binding=nil)
            raise RuntimeError, "Folder #{source_path} does not exist" unless File.exist?(source_path)
            raise RuntimeError, "Folder #{dest_path} already exists" if File.exist?(dest_path)
            FileUtils.mkdir_p(dest_path)
            erb_binding ||= binding
            Find.find(source_path) do |sp|
                next if sp == source_path
                rel_path = sp[source_path.length+1..-1]
                dp = rel_path
                replacements.each do |search, replace|
                    dp.gsub!(search, replace)
                end
                if (File.directory?(sp))
                    FileUtils.mkdir(dest_path+'/'+dp)
                else
                    dst = File.new(dest_path+'/'+dp, 'w')
                    res = ERB.new(IO.read(sp)).result(erb_binding)
                    dst.puts(res)
                    dst.close
                end
            end
        end
        
    end
    
end