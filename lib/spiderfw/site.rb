module Spider

    class Site
        attr_reader   :domain
        attr_accessor   :port
        attr_accessor :ssl_port
        attr_accessor :_auto
        
        def initialize(domain, port, ssl_port=nil)
            @domain = domain
            @port = port
            @ssl_port = ssl_port
        end
        
        def save_cache
            File.open(self.class.cache_file, 'w') do |f|
                f.puts(Marshal.dump(self))
            end
        end
        
        def self.load_cache
            begin
                Marshal.restore(File.read(self.cache_file))
            rescue
                nil
            end
        end
        
        def self.cache_file
            @cache_file ||= File.join(Spider.paths[:var], 'site')
        end
        
        def ssl?
            @ssl_port
        end
        
        def auto?
            @_auto
        end
        
        def to_s
            s = "http://#{@domain}"
            s += ":#{@port}" if @port != 80
            s
        end
        
        def ssl_to_s
            s = "https://#{@domain}"
            s += ":#{@ssl_port}" if @ssl_port != 443
            s
        end
        
    end 

end
