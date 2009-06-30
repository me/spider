module Spider
    
    config_option 'worker.fork', :type => Spider::DataTypes::Bool, :default => true
    config_option 'worker.detach', :type => Spider::DataTypes::Bool, :default => true
    
end