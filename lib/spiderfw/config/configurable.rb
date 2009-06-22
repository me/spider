require 'spiderfw/config/configuration'

module Spider

    module Configurable
#        @@configuration = $configuration ? $configuration : Configuration.new

        def self.included receiver
            receiver.class_eval do
                @configuration = $configuration ? $configuration : Configuration.new
                def self.configuration_prefix(prefix)
                    @configuration.create_prefix(prefix)
                    @configuration = @configuration[prefix]
                end
                
                 # FIXME: doesn't use the prefix?
                 def self.config_option(name, description, params={})
                     Spider.configuration.config_option(name, description, params)
                 end
                 
                 def self.conf_alias(name, aliases=nil)
                     Spider.configuration.conf_alias(name, aliases)
                 end
        
                 def self.config_include_set(name)
                     @configuration.include_set(name)
                 end

             end
        end

        def config_include_set(name)
            Spider.configuration.include_set(name)
        end

    end

end