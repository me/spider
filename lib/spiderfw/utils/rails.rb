require 'spiderfw/model/active_record'

module Spider
    
    class Rails
    
        def initialize(path, options={})
            @path = path
            @options = options
            @rails_app_name = options[:app_name]
        end
        
        def start
            return if @started
            Spider::Logger.info("Loading Rails environment at #{@path}")
            require "#{@path}/config/environment.rb"
            ActiveRecord::Base.instance_eval do
                def self.spider_model
                    @spider_model
                end
                def self.spider_model=(val)
                    @spider_model = val
                end
            end
            @started = true
        end
        
        def started?
            @started
        end
        
        def define_models(container)
            start unless started?
            ar_models = []
            
            self.class.active_record_models.each do |mod|
                Spider::Model::create_ar_classes(mod, container)
            end
            done = {}
            # Spider::Model.ar_models.each do |mod|
            #     mod.ar_through_models.each do |m|
            #         next if done[m]
            #         m.define_from_ar
            #         done[m] = true
            #     end
            # end
            
            Spider::Model.ar_models.each do |mod|
                #next if done[mod]
                next unless mod.ar_defined
                mod.rails_app_name = @rails_app_name
                mod.define_from_ar
                #done[mod] = true
            end
        end
        
        class <<self
            def active_record_models(mod=nil)
                mod ||= Object
                res = []

                mod.constants.each do |const|
                    kl = mod.const_get(const.to_sym)
                    if (kl.is_a?(Class))
                        res << kl if kl < ::ActiveRecord::Base
                    # elsif(kl.is_a?(Module))
                    #                        res += active_record_models(kl)
                    end
                    
                end
                return res
            end
        end
        
    end
    
    
end