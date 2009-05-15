require 'spiderfw/controller/session'
require 'fileutils'

module Spider
    
    class FileSession < Session
        
        class << self
            
            def setup
                @sync ||= Sync.new
            end

            def []=(sid, data)
                dir = Spider.conf.get('session.file.path')
                FileUtils.mkpath(dir)
                path = "#{dir}/#{sid}"
                
                @sync.lock(Sync::EX)
                f = File.new(path, 'w+')
                f.flock(File::LOCK_EX)
                f.puts(Marshal.dump(data))
                f.flush
                f.flock(File::LOCK_UN)
                f.close
                @sync.lock(Sync::UN)
            end
        
            def [](sid)
                check_purge
                dir = Spider.conf.get('session.file.path')
                path = "#{dir}/#{sid}"
                data = nil
                if (File.exist?(path))
                    @sync.lock(Sync::SH)
                    f = File.new(path, 'r+')
                    f.flock(File::LOCK_SH)
                    begin
                        data = Marshal.restore(f.read)
                    rescue => exc
                        Spider::Logger.error("Corrupt session")
                    end
                    mtime = f.mtime
                    f.flock(File::LOCK_UN)
                    f.close
                    @sync.lock(Sync::UN)
                end
                return data
            end
            
            def purge(life)
                dir = Spider.conf.get('session.file.path')
                Find.find(dir) do |path|
                    next unless File.file?(path)
                    File.unlink(path) if File.exist?(path) && (File.mtime(path) + life < Time.now)
                end
            end
                
            
        end
        
        
        
        
    end
    
    
end
