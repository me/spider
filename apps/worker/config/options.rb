module Spider
    
    config_option 'worker.fork', :type => Spider::DataTypes::Bool, :default => lambda{
      RUBY_PLATFORM =~ /win32|mingw32/ ? false : true
    }
    config_option 'worker.detach', :type => Spider::DataTypes::Bool, :default => true
    config_option 'worker.jobs_interval', _("Seconds between each jobs run"), :type => Fixnum, :default => 60
    
end
