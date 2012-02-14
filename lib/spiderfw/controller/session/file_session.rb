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
                f = File.new(path, 'wb+')
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
                    f = File.new(path, 'rb+')
                    f.flock(File::LOCK_SH)
                    begin
                        data = Marshal.restore(f.read)
                    rescue => exc
                        Spider::Logger.error("Corrupt session: #{exc.message}")
                        data = {}
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
                @sync.lock(Sync::EX)
                Find.find(dir) do |path|
                    next unless File.file?(path)
                    File.unlink(path) if File.exist?(path) && (File.mtime(path) + life < Time.now)
                end
                @sync.lock(Sync::UN)
            end
            
            def delete(sid)
                dir = Spider.conf.get('session.file.path')
                return unless File.exist?(dir+'/'+sid)
                @sync.lock(Sync::EX)
                f = File.new(dir+'/'+sid)
                f.flock(File::LOCK_EX)
                File.unlink(dir+'/'+sid)
                f.flock(File::LOCK_UN)
                f.close
                @sync.lock(Sync::UN)
            end
                
            
        end
        
        
        
        
    end
    
    
end
