module Spider
    
    class SetupTask
        attr_reader :path, :version
        attr_accessor :up, :down, :app
        
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
            intance_eval(&@up)
            sync_schema unless @no_sync || @sync_done
        end
        
        def do_down
            instance_eval(&@down)
        end
        
        def no_sync_schema
            @no_sync = true
        end
        
        def sync_schema(*models)
            if models[-1].is_a?(Hash)
                options = models.pop
            else
                options = {}
            end
            if models.empty?
                models = @app.models.reject{ |m| !(m < Spider::Model::Managed) }
            end
            Spider::Model.sync_schema(
                model, options[:force], 
                :drop_fields => options[:drop_fields], 
                :update_sequences => options[:update_sequences], 
                :no_foreign_key_constraints => options[:no_foreign_key_constraints]
            )
            @sync_done = true
        end
        
        def sync_schema!(*models)
            if models[-1].is_a?(Hash)
                options = models.pop
            else
                options = {}
            end
            options[:force] = true
            args = models + [options]
            sync_schema(*args)
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