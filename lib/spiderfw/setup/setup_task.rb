module Spider
    
    class SetupTask
        attr_reader :path, :version
        attr_accessor :up, :down
        
        class <<self
            def tasks
                @tasks ||= {}
            end
            
            # def inherited(subclass)
            #     @last_class = subclass
            # end
            
            def load(path)
                crit = Thread.critical
                Thread.critical = true unless crit
                Kernel.load(path)
                obj = self.new(path)
                obj.up = Setup.up
                obj.down = Setup.down
                #obj = @last_class.new(path)
#                Kernel.send(:remove_const, @last_class.name)
                #@last_class = nil
                Thread.critical = crit
                return obj
            end
        end
        
        def initialize(path, up=nil, down=nil)
            @path = path
            name = File.basename(path, '.rb')
            if (name =~ /^((?:\d\.?){1,3})/)
                version = $1
                version = version[0..-2] if version[-1].chr == '.'
                desc = name[(version.length+1)..-1]
            else
                version = name
                desc = nil
            end
            @version = Gem::Version.new(version)
            @desc = desc
        end
        
        def do_up
            @up.call
        end
        
        def do_down
            @down.call
        end
        

    end
    
    module Setup
        
        
        def self.up(&proc)
            @up = proc if proc
            @up
        end
        
        def self.down(&proc)
            @down = proc if proc
            @down
        end
        
    end
    
end