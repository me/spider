require 'spiderfw/model/migrations'

module Spider
    
    class SetupTask
        attr_reader :path, :version
        attr_accessor :before, :up, :down, :cleanup, :sync_models, :app, :interactive
        
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
                obj.interactive = Setup.interactive?
                #obj = @last_class.new(path)
#                Kernel.send(:remove_const, @last_class.name)
                #@last_class = nil
                Thread.critical = crit
                obj.do_before
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

        def dir
            File.join(::File.dirname(@path), @version.to_s)
        end

        def do_before
            return unless @before
            Spider::Model::Managed.no_set_dates = true
            instance_eval(&@before)
            #sync_schema unless @no_sync || @sync_done
            Spider::Model::Managed.no_set_dates = false
        end
        
        def do_up
            return unless @up
            Spider::Model::Managed.no_set_dates = true
            instance_eval(&@up)
            #sync_schema unless @no_sync || @sync_done
            Spider::Model::Managed.no_set_dates = false
        end
        
        def do_down
            return unless @down
            Spider::Model::Managed.no_set_dates = true
            instance_eval(&@down)
            Spider::Model::Managed.no_set_dates = false
        end

        def do_cleanup
            instance_eval(&@cleanup) if @cleanup
        end

        def do_sync
            sync_schema
        end

        def sync_schema(*models)
            had_models = models
            models = @sync_models if models.blank?
            return unless models
            @sync_options = models.pop if models.last.is_a?(Hash)
            models = models.map{ |m| 
                m <= Spider::App ? m.models.reject{ |n| n <= Spider::Migrations::PreviousModel } : m 
            }.flatten
            @sync_options ||= {}
            options = {
                :no_foreign_key_constraints => true,
                :force => false
            }.merge(@sync_options)
            models.each do |m|
                next unless m.mapper.respond_to?(:sync_schema)
                m.mapper.sync_schema(options[:force], options)
            end
        end

        def confirm(msg, default=nil)
            yes = _("yes")
            no = _("no")
            y = yes[0].chr
            n = no[0].chr
            if default == true
                y = y.upcase
            elsif default == false
                n = n.upcase
            end

            good = false

            while !good
                print "#{msg} [#{y}/#{n}]: "
                res = $stdin.gets.strip
                
                good = true
                if res == yes || res == y
                    res = true
                elsif res == no || res == n
                    res = false
                elsif res.blank? && !default.nil?
                    res = default
                else
                    good = false
                end

            end

            return res


        end

        def warn(msg)
            puts msg
            print "\n"+_("Press any key to continue ")
            $stdin.getc
            print "\n"
        end

        def interactive?
            @interactive
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

        def setup_previous_templates(templates)
            msg = ""
            templates.each do |t|
                from = File.join(self.dir, t[:prev])
                to = File.join(Spider.paths[:root], 'views', t[:dest])
                unless File.file?(to)
                    FileUtils.mkdir_p(File.dirname(to))
                    FileUtils.cp(from, to)
                    msg += _(t[:msg]) % to
                    msg += "\n"
                end
            end
            warn(msg) unless msg.blank?
        end

        def print_release_notes
            readme = File.join(self.dir, "README.#{Spider.locale.language}")
            unless File.file?(readme)
                readme = File.join(self.dir, "README")
            end
            if File.file?(readme)
                puts File.read(readme)
            end

        end
        

    end
    
    module Setup

        def self.task(&proc)
            self.instance_eval(&proc)
        end

        # TODO: pass options
        def self.sync_schema(*models)
            options = models.pop if models.last.is_a?(Hash)
            @sync_models = models
            @sync_options = options || {}
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

        def self.interactive!
            @interactive = true
        end

        def self.interactive?
            !!@interactive
        end
        
    end
    
end
