require 'spiderfw/controller/session'
require 'fileutils'

module Spider
    
    class FileSession < Session
        
        class << self
        
            def []=(sid, data)
                dir = Spider.conf.get('session.file.path')
                FileUtils.mkpath(dir)
                path = "#{dir}/#{sid}"
                f = File.new(path, 'w')
                f.flock(File::LOCK_EX)
                f.puts(Marshal.dump(data))
                f.flock(File::LOCK_UN)
                f.close
            end
        
            def [](sid)
                check_purge
                dir = Spider.conf.get('session.file.path')
                path = "#{dir}/#{sid}"
                if (File.exist?(path))
                    f = File.new(path, 'r')
                    f.flock(File::LOCK_SH)
                    data = Marshal.restore(f.read)
                    mtime = f.mtime
                    f.flock(File::LOCK_UN)
                    f.close
                end
                return {:data => data, :mtime => mtime}
            end
            
            def purge(life)
                dir = Spider.conf.get('session.file.path')
                Find.find(dir) do |path|
                    next unless File.file?(path)
                    File.unlink(path) if (File.mtime + life < Time.now)
                end
            end
                
            
        end
        
        
        
        
    end
    
    
end