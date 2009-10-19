module Spider
    
    config_option 'cas.expire_sessions', :type => Spider::DataTypes::Bool, :default => false
    config_option 'cas.login_ticket_expiry', :type => Fixnum, :default => 5*60
    config_option 'cas.service_ticket_expiry', :type => Fixnum, :default => 5*60
    config_option 'cas.proxy_granting_ticket_expiry', :type => Fixnum, :default => 48*60*60
    config_option 'cas.ticket_granting_ticket_expiry', :type => Fixnum, :default => 48*60*60
    
end