module Spider
    
    class SetupTask
        attr_reader :path, :version
        
        class <<self
            def tasks
                @tasks ||= {}
            end
            
            def inherited(subclass)
                @last_class = subclass
            end
            
            def load(path)
                crit = Thread.critical
                Thread.critical = true unless crit
                Kernel.load(path)
                obj = @last_class.new(path)
#                Kernel.send(:remove_const, @last_class.name)
                @last_class = nil
                Thread.critical = crit
                return obj
            end
        end
        
        def initialize(path)
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

    end
    
end