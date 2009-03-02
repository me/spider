module Spider; module WebDAV; module VFS
    
    class Properties
		attr_reader :filename
		
		def initialize(vfs, filename)
			@filename = filename
			@vfs = vfs
		end
		
		def displayname
			File.basename(@filename)
		end
		
		def ctime
		end
		
		def mtime
		end
		
		def etag
		end
		
		def content_type
			@vfs.directory?(@filename) ? "httpd/unix-directory" : "text/plain"
		end
		
		def size
			0
		end
		
	end
	
	class PropertyNotFound < RuntimeError
	    attr_reader :file
	    def initialize(file=nil)
	        @file = file
        end
    end
	
end; end; end