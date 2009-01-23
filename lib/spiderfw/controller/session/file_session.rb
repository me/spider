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
                dir = Spider.conf.get('session.file.path')
                path = "#{dir}/#{sid}"
                if (File.exist?(path))
                    f = File.new(path, 'r')
                    f.flock(File::LOCK_SH)
                    data = Marshal.restore(f.read)
                    f.flock(File::LOCK_UN)
                    f.close
                end
                return data
            end
            
        end
        
        
        
        
    end
    
    
end