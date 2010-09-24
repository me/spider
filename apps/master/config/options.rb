module Spider
    
    config_option 'master.scout_plugins_path', _("Path to the scout plugins folder"), :type => String
    config_option 'master.from_email', _("From address for e-mail sent by master"), :type => String, :default => 'spider-master@spiderfw.net'
    
end