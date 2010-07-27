module Spider
    
    config_option 'cas.expire_sessions', :type => Spider::DataTypes::Bool, :default => false
    config_option 'cas.login_ticket_expiry', :type => Fixnum, :default => 5*60
    config_option 'cas.service_ticket_expiry', :type => Fixnum, :default => 5*60
    config_option 'cas.proxy_granting_ticket_expiry', :type => Fixnum, :default => 48*60*60
    config_option 'cas.ticket_granting_ticket_expiry', :type => Fixnum, :default => 48*60*60
    config_option 'cas.saml1_1_compatible', :type => Spider::DataTypes::Bool, :default => false
    config_option 'cas.saml_compliant_tickets', :type => String, :choices => [false, '1', '2', '4'], :default => lambda{
        Spider.conf.get('cas.saml1_1_compatible') ? '1' : false
    }
    
end