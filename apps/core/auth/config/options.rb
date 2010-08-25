module Spider
    
    config_option 'auth.enable_superuser_backdoor', _("Allow a backdoor for the superuser to login as any user"), :type => Spider::DataTypes::Bool,
        :default => false
    
end