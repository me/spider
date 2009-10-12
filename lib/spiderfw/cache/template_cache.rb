require 'fileutils'
require 'sync'

module Spider
    
    class TemplateCache
        include Logger
        
   
        def initialize(root_path)
            FileUtils.mkpath(root_path)
            @path = root_path
            @invalid = {}
        end
        
        def fetch(path, &block)
            return refresh(path, &block) unless fresh?(path)
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
            full_path = get_location(path)
            exists = File.exist?(full_path)
            if (Spider.config.get('template.cache.no_check') && exists)
                return true
            end
            return false if @invalid[path]
            global_reload_file = "#{Spider.paths[:tmp]}/templates_reload.txt"
            check_file = "#{full_path}/check"
            return false unless File.exist?(check_file)
            if (File.exist?("#{Spider.paths[:tmp]}/templates_reload.txt"))
                return false if (File.mtime(global_reload_file) > File.mtime(check))
            end
            return true unless Spider.conf.get('template.cache.check_files')
            lock_file = File.new(full_path)
            lock_file.flock(File::LOCK_SH)
            File.new(full_path).flock(File::LOCK_SH)
            # TODO: maybe insert here an (optional) tamper check 
            # that looks if the cache mtime is later then the saved time
            Marshal.load(IO.read(check_file)).each do |check, time|
                debug("Template file #{check} changed, refreshing cache")
                return false if File.mtime(check) > time
            end
            lock_file.flock(File::LOCK_UN)
            return true
        end
        
        def invalidate(path)
            @invalid[path] = true
        end
        
        def refresh(path, &block)
            debug("Refreshing cache for #{path}")
            res = block.call()
            write_cache(path, res)
            return res
        end
        
        def get_compiled_template(path)
            compiled = Spider::CompiledTemplate.new
            compiled.cache_path = path
            init_code = IO.read(path+'/init.rb')
            run_code = IO.read(path+'/run.rb')
            block = Spider::TemplateBlocks::CompiledBlock.new(init_code, run_code)
            compiled.block = block
            Dir.new(path).each do |entry|
                next if entry[0].chr == '.'
                sub_path = "#{path}/#{entry}"
                next if entry == '__info'
                next unless File.directory?(sub_path)
                compiled.subtemplates[entry] = get_compiled_template(sub_path)
            end
            return compiled
        end
        
        def load_cache(template_path)
            debug("Using cached #{template_path}")
            full_path = get_location(template_path)
            lock_file = File.new(full_path)
            lock_file.flock(File::LOCK_SH)
            compiled = get_compiled_template(full_path)
            lock_file.flock(File::LOCK_UN)
            return compiled
        end
        
        def write_compiled_template(compiled, path)
            compiled.cache_path = path
            File.open(path+'/init.rb', 'w') do |file|
                file.puts(compiled.block.init_code)
            end
            File.open(path+'/run.rb', 'w') do |file|
                file.puts(compiled.block.run_code)
            end
            compiled.subtemplates.each do |id, sub|
                sub_path = "#{path}/#{id}"
                FileUtils.mkpath(sub_path)
                write_compiled_template(sub, sub_path)
            end
            compiled.devel_info.each do |name, val|
                FileUtils.mkpath("#{path}/__info")
                sub_path = "#{path}/__info/#{name}"
                File.open(sub_path, 'w') do |f|
                    f.puts(val)
                end
            end
        end
        
        def write_cache(template_path, compiled_template)
            full_path = get_location(template_path)
            FileUtils.mkpath(full_path)
            lock_file = File.new(full_path)
            lock_file.flock(File::LOCK_EX)
            write_compiled_template(compiled_template, full_path)
            modified = compiled_template.collect_mtimes
            File.open(full_path+'/check', 'w') do |file|
                file.puts(Marshal.dump(modified))
            end
            lock_file.flock(File::LOCK_UN)
        end
        
        
        
        
    end
    
    
end