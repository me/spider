module Spider
    
    config_option 'worker.enable', :type => Spider::DataTypes::Bool, :default => lambda{ Spider.config.get('runmode') == 'devel' ? false : true }
    config_option 'worker.fork', :type => Spider::DataTypes::Bool, :default => lambda{
      RUBY_PLATFORM =~ /win32|mingw32/ ? false : true
    }
    config_option 'worker.detach', :type => Spider::DataTypes::Bool, :default => true
    config_option 'worker.jobs_interval', _("Seconds between each jobs run"), :type => Fixnum, :default => 60
    config_option 'worker.keep_running', _('Keep the worker running after the main process shuts down'), :type => Spider::Bool,
    	:default => lambda{ Object.const_defined?(:PhusionPassenger) ? true : false }
    
end
