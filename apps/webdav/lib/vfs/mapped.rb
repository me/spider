require 'apps/webdav/lib/vfs/abstract'
require 'apps/webdav/lib/locking'

module Spider; module WebDAV; module VFS

    class Mapped < Abstract
        include Locking
        attr_reader :name, :props

        def initialize(name=nil)
            @entries = {}
            @name = name || '/'
            @props = {
                :ctime => Time.now,
                :mtime => Time.now,
                :size => 0,
                :executable => false
            }
        end

        def get(path)
            return self unless path
            path = path.sub(/^\/+/, '')
            return self if (path.empty?)
            first, rest = path.split('/', 2)
            raise Errno::ENOENT unless self[first]
            return [self[first], rest]
        end

        def [](name)
            @entries[name]
        end

        def []=(name, value)
            @entries[name] = value
        end

        def stream(path, acc)
            return Errno::ENOENT if directory?(path)
            vfs, rest = get(path)
            vfs.stream(rest, acc){ |f| yield f }
            # if (vfs.is_a?(MappedFile))
            #     return File.open(vfs.real_path, acc){ |f| yield f } 
            # else
            #     
            # end
        end

        def directory?(path)
            vfs, rest = get(path)
            return vfs.directory?(rest) if rest
            return true if (vfs.is_a?(Mapped))
            return false
        end

        def mkdir(path)
            vfs, rest = get(path)
            if (rest)
                return vfs.mkdir(rest) if rest
            end
            return self[path] = Mapped.new(path)
        end

        def touch(path)
            begin
                vfs, rest = get(path)
                return vfs.touch(rest)
            rescue Errno::ENOENT
                return self[path] = VirtualFile.new(path)
            end
        end

        def rm(path)
            vfs, rest = get(path)
            return vfs.rm(rest) if rest
            return @entries.delete(path)
        end

        def cp(src, dst, recursive=true)
            raise Forbidden, "Copy #{src} -> #{dst}"
        end

        def mv(src, dst)
            raise Forbidden, "Move #{src} -> #{dst}"
        end

        def exists?(path)
            begin
                vfs, rest = get(path)
            rescue Errno::ENOENT
                return false
            end
            return vfs.exists?(rest) if rest
            return true
        end

        def ls(path)
            vfs, rest = get(path)
            if (vfs == self)
                do_ls { |f| yield f }
                return
            end
            return vfs.ls(rest){ |f| yield f }
        end

        def do_ls
            @entries.each do |f|
                yield f
            end
        end

        def properties(path)
            vfs, rest = get(path)
            return vfs.properties(rest) if rest
            return MappedProperties.new(self, vfs) if (vfs.is_a?(Mapped))
            return MappedFileProperties.new(self, vfs) if (vfs.is_a?(MappedFile))
            return VirtualFileProperties.new(self, vfs) if (vfs.is_a?(VirtualFile))
            raise Errno::ENOENT
        end




        class MappedProperties

            def initialize(vfs, mapped)
                @vfs = vfs
                @mapped = mapped
            end

            def ctime
                @mapped.props[:ctime]
            end

            def mtime
                @mapped.props[:mtime]
            end

            def size
                @mapped.props[:size]
            end

            def etag
                sprintf('%x-%x-%x', 0, size, mtime.to_i)
            end

            def content_type
                "httpd/unix-directory"
            end
            
            def displayname
                @mapped.name
            end

            def to_s
                "file #{@filename}, ctime #{ctime}, mtime #{mtime}"
            end

            def apache_org_executable
                return @mapped.props[:executable] ? 'T' : 'F'
            end

        end


        class MappedFileProperties < VFS::Local::Properties

            def initialize(vfs, mapped)
                super(vfs, mapped.real_path)
            end

        end

        class VirtualFileProperties < MappedProperties

            def content_type
                @mapped.props[:mime_type]
            end

        end


    end

    class MappedFile
        attr_reader :name, :real_path, :props

        def initialize(real_path, name='')
            @name ||= File.basename(real_path)
            @real_path = real_path
            @props = {
                :ctime => Time.now,
                :mtime => Time.now,
                :size => 0,
                :executable => false
            }
        end

        def stream(dummy_path, acc)
            File.open(@real_path, acc){ |f| yield f }
        end

        def touch(dummy_path)
            File.new(@real_path, 'w').close
        end
        
        def rm
            File.unlink(@real_path)
        end

    end

    class VirtualFile
        attr_reader :name, :props

        def initialize(name)
            @name = name
            @props = {
                :ctime => Time.now,
                :mtime => Time.now,
                :size => 0,
                :executable => false
            }
        end

        def stream
        end

        def touch
            @props[:mtime] = Time.now
        end 

    end

end; end; end