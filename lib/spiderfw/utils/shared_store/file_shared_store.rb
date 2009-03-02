require 'spiderfw/utils/shared_store'
require 'fileutils'

module Spider; module Utils
    
    class FileSharedStore < SharedStore
        attr_reader :path
        
        def initialize(config={})
            super
            @path = config[:path]
            if (!@path && config[:name])
                @path = Spider.conf.get('shared_store.file.base_path')+'/'+config[:name]
            end
            if (!@path)
                raise ArgumentError, "You must supply the FileSharedStore with a path, or a name a configured base path"
            end
            FileUtils.mkpath(@path)     
        end
        
        def [](key, &proc)
            path = map_path(key)
            if (File.exist?(path))
                f = File.new(path, 'r')
                f.flock(File::LOCK_SH)
                data = Marshal.restore(f.read)
                f.flock(File::LOCK_UN)
                f.close
            end
            return data
        end
        
        def []=(key, value)
            path = map_path(key)
            f = File.new(path, 'w')
            f.flock(File::LOCK_EX)
            f.puts(Marshal.dump(value))
            f.flock(File::LOCK_UN)
            f.close
        end

        
        def delete(key)
            File.unlink(map_path(key))
        end
        
        def include?(key)
            File.exist?(map_path(key))
        end
        
        def map_path(key)
            "#{@path}/key"
        end
        
        def each_key
            Dir.new(@path).each do |key|
                next unless File.file?(@path+'/'+key)
                yield key
            end
        end
        
        
    end
    
end; end