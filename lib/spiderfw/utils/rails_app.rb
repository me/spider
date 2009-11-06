require 'spiderfw/utils/rails'

module Spider
    
    module RailsApp
    
        def self.included(mod)
            mod.extend(ClassMethods)
            mod.instance_eval do
                include Spider::App
            end
        end
        
        
    
        module ClassMethods
        
            def rails(path, options={})
                @options = options
                @rails = Spider::Rails.new(path, options)
            end

            def rails_app_name=(val)
                @rails_app_name = val
            end    
            
            def define_rails_models
                @rails.define_models(self)
            end
            
            def const_missing(name)
                unless @options[:reload_models]
                    local = "#{self.app.models_path}/#{Inflector.underscore(name)}.rb"
                    local_ext = "#{self.app.models_path}/extended/#{Inflector.underscore(name)}.rb"
                end
                if (local && File.exist?(local))
                    require local
                else
                    @rails.start
                    define_rails_models
                end
                if (File.exist?(local_ext))
                    require local_ext
                end
                klass = const_get(name)
                return klass if klass
                super
            end
        
        end    
        
    end
end