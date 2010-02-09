require 'apps/webdav/lib/vfs/abstract'
require 'apps/webdav/lib/locking'

module Spider; module WebDAV; module VFS

    class Local < Abstract
        include Locking
        
        class Properties < VFS::Properties
			def initialize(vfs, filename)
				super
                
				@stat = File.exist?(@filename) ? File.lstat(@filename) : OpenStruct.new
			end
			
			def ctime
				@stat.ctime || Time.now
			end
			
			def mtime
				@stat.mtime || Time.now
			end
			
			def etag
				sprintf('%x-%x-%x', @stat.ino, self.size, self.mtime.to_i)
			end
			
			def content_type
				File.directory?(@filename) ? "httpd/unix-directory" : MIME::Types.type_for(@filename)[0].to_s
			end
			
			def size
				File.file?(@filename) or return 0
				@stat.size
			end
			
			def to_s
			    "file #{@filename}, ctime #{ctime}, mtime #{mtime}"
		    end
		    
		    def apache_org_executable
		        raise PropertyNotFound.new(@filename) unless File.file?(@filename)
		        return @stat.executable? ? 'T' : 'F'
	        end
		end

        def initialize(path)
            @base_path = path
        end

        def map_path(path)
            path = '/' + path unless path[0].chr == '/'
            res = @base_path+path
            res
        end

        def stream(path, acc)
            full_path = map_path(path)
            File.touch(full_path) unless File.exist?(full_path)
            File.open(full_path, acc){ |f| yield f } 
        end
        
        def directory?(path)
            File.directory?(map_path(path))
        end
        
        def mkdir(path)
            Dir.mkdir(map_path(path))
        end
        
        def touch(path)
            File.new(map_path(path), 'w').close
        end
        
        def rm(path)
            FileUtils.rm_rf(map_path(path))
        end
        
        def cp(src, dst, recursive=true)
            real_src = map_path(src)
            real_dst = map_path(dst)
            if directory?(src)
				if recursive
					FileUtils.cp_r(real_src, real_dest, {:preserve => true})
				else
					mkdir(real_dst)
				
					st = File.stat(real_src)
				
					begin
						# Make sure that the new directory has the same
						# access and modified time
						File.utime(st.atime, st.mtime, real_dst)
					rescue
						# simply ignore
					end
				end
			else
				FileUtils.cp(real_src, real_dst, {:preserve => true})
			end
        end
        
        def mv(src, dst)
            File.rename(map_path(src), map_path(dst))
        end
        
        def exists?(path)
            File.exists?(map_path(path))
        end
        
        def ls(dirname)
            Dir.entries(map_path(dirname)).each do |f|
				next if f == ".." || f == "."
				next if filtered?(f)
		
				yield f
			end
		end
		
		def properties(path)
		    Properties.new(self, map_path(path))
	    end

    end

end; end; end