require 'spiderfw/model/migrations'

module Spider
    
    class SetupTask
        attr_reader :path, :version
        attr_accessor :before, :up, :down, :cleanup, :sync_models, :app
        
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
                obj.before = Setup.before
                obj.up = Setup.up
                obj.down = Setup.down
                obj.cleanup = Setup.cleanup
                obj.sync_models = Setup.sync_models
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
            Spider::Model::Managed.no_set_dates = true
            instance_eval(&@up)
            #sync_schema unless @no_sync || @sync_done
            Spider::Model::Managed.no_set_dates = false
        end
        
        def do_down
            Spider::Model::Managed.no_set_dates = true
            instance_eval(&@down)
            Spider::Model::Managed.no_set_dates = false
        end

        def do_cleanup
            instance_eval(&@cleanup)
        end

        def do_sync
            options = {
                :no_foreign_key_constraints => true
            }
            @sync_models.each do |m|
                m.mapper.sync_schema(false, options)
            end
        end
        
        # def no_sync_schema
        #     @no_sync = true
        # end
        
        # def sync_schema(*models)
        #     if models[-1].is_a?(Hash)
        #         options = models.pop
        #     else
        #         options = {}
        #     end
        #     if models.empty?
        #         models = @app.models.reject{ |m| !(m < Spider::Model::Managed) }
        #     end
        #     Spider::Model.sync_schema(
        #         model, options[:force], 
        #         :drop_fields => options[:drop_fields], 
        #         :update_sequences => options[:update_sequences], 
        #         :no_foreign_key_constraints => options[:no_foreign_key_constraints]
        #     )
        #     @sync_done = true
        # end
        
        # def sync_schema!(*models)
        #     if models[-1].is_a?(Hash)
        #         options = models.pop
        #     else
        #         options = {}
        #     end
        #     options[:force] = true
        #     args = models + [options]
        #     sync_schema(*args)
        # end
        

    end
    
    module Setup

        def self.task(&proc)
            self.instance_eval(&proc)
        end

        # TODO: pass options
        def self.sync_schema(*models)
            @sync_models = models
        end

        def self.sync_models
            @sync_models
        end

        def self.before(&proc)
            @before = proc if proc
            @before
        end
        
        def self.up(&proc)
            @up = proc if proc
            @up
        end
        
        def self.down(&proc)
            @down = proc if proc
            @down
        end

        def self.cleanup(&proc)
            @cleanup = proc if proc
            @cleanup
        end
        
    end
    
end
