require 'apps/webdav/lib/vfs/properties'
require 'mime/types'

module Spider; module WebDAV; module VFS
    
    class Abstract
       
       def self.locking?
           false
       end
       
       def self.config
           {:MimeTypes => ::MIME::Types}
       end
       
       def locking?
           self.class.locking?
       end
       
       def map_path(path)
           path
       end
       
       def stream(filename, acc)
           raise NotImplementedError
       end
       
		def iostream(filename)
			stream(filename, "w+") {|f| yield f}
		end
		
		def ostream(filename)
			stream(filename, "w") {|f| yield f}
		end
		
		def istream(filename)
			stream(filename, "r") {|f| yield f}
		end
		
		def directory?(path)
		    raise NotImplementedError
	    end
	    
	    def mkdir(path)
	        raise NotImplementedError
        end
        
        def rm(path)
            raise NotImplementedError
        end
        
        def copy(src, dest, recursive=true)
            raise NotImplementedError
        end
        
        def mv(src, dst)
            raise NotImplementedError
        end
        
        def exists?(filename)
            raise NotImplementedError
        end
        
        def ls(path)
            raise NotImplementedError
        end
        
        def filtered?(path)
            return false
        end
        
		def properties(path)
			Properties.new(self, map_path(path))
		end 
        
    end
    
end; end; end