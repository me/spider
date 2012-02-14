require 'spiderfw/utils/shared_store'
require 'fileutils'

module Spider; module Utils
    
    # Implementation of the SharedStore in the filesystem.
    # This is a persistent store, accessible by different threads and processes at once.
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
            @sync = Sync.new
        end
        
        def [](key)
            path = map_path(key)
            if (File.exist?(path))
                @sync.lock(Sync::SH)
                f = File.new(path, 'rb')
                f.flock(File::LOCK_SH)
                data = Marshal.restore(f.read)
                f.flock(File::LOCK_UN)
                f.close
                @sync.lock(Sync::UN)
            end
            return data
        end
        
        def []=(key, value)
            path = map_path(key)
            @sync.lock(Sync::EX)
            f = File.new(path, 'wb')
            f.flock(File::LOCK_EX)
            f.puts(Marshal.dump(value))
            f.flush
            f.flock(File::LOCK_UN)
            f.close
            @sync.lock(Sync::UN)
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