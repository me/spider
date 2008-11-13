require 'fileutils'
require 'sync'

module Spider
    
    class TemplateCache
        include Logger
   
        def initialize(root_path)
            debug("Initializing TemplateCache in #{root_path}")
            FileUtils.mkpath(root_path)
            @path = root_path
            @invalid = {}
        end
        
        def fetch(path, template_obj, &block)
            return refresh(path, template_obj, &block) unless fresh?(path)
            return load_cache(path)
        end
        
        def get_location(path, &block)
            refresh(path, &block) if (block && !fresh?(path))
            return @path+'/'+path
        end
        
        def fresh?(path)
            if Spider.config.get('template.cache.disable')
                debug("Cache disabled, recreating #{path}")
                return false
            end
            return false if @invalid[path]
            full_path = get_location(path)
            return false unless File.exist?(full_path+'/check')
            lock_file = File.new(full_path)
            lock_file.lock(File::LOCK_SH)
            File.new(full_path).lock(File::LOCK_SH)
            # TODO: maybe insert here an (optional) tamper check 
            # that looks if the cache mtime is later then the saved time
            Marshal.load(IO.read(full_path+'/check')).each do |check, time|
                debug("Template file #{check} changed, refreshing cache")
                return false if File.mtime(check) > time
            end
            lock_file.lock(File::LOCK_UN)
            return true
        end
        
        def invalidate(path)
            @invalid[path] = true
        end
        
        def refresh(path, template_obj, &block)
            debug("Refreshing cache for #{path}")
            res = block.call()
            write_cache(path, res, template_obj)
            return res
        end
        
        def load_cache(template_path)
            debug("Using cached #{template_path}")
            full_path = get_location(template_path)
            lock_file = File.new(full_path)
            lock_file.lock(File::LOCK_SH)
            init_code = IO.read(full_path+'/init.rb')
            run_code = IO.read(full_path+'/run.rb')
            lock_file.lock(File::LOCK_UN)
            return Spider::TemplateBlocks::CompiledBlock.new(init_code, run_code)
        end
        
        def write_cache(template_path, compiled_block, template_obj)
            full_path = get_location(template_path)
            lock_file = File.new(full_path)
            lock_file.lock(File::LOCK_EX)
            FileUtils.mkpath(full_path)
            File.open(full_path+'/init.rb', 'w') do |file|
                file.puts(compiled_block.init_code)
            end
            File.open(full_path+'/run.rb', 'w') do |file|
                file.puts(compiled_block.run_code)
            end
            modified = {
                template_obj.path => File.mtime(template_obj.path)
            }
            File.open(full_path+'/check', 'w') do |file|
                file.puts(Marshal.dump(modified))
            end
            lock_file.lock(File::LOCK_UN)
        end
        
        
        
        
    end
    
    
end