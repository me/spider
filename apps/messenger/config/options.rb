module Spider
    
    config_option 'messenger.smtp.address', _("SMTP address to use when sending mail"), :default => 'localhost'
    config_option 'messenger.smtp.port', _("SMTP port"), :default => 25
    config_option 'messenger.smtp.domain', _("HELO domain"), :default => 'localhost'
    config_option 'messenger.smtp.username', _("SMTP authentication username"), :default => nil
    config_option 'messenger.smtp.password', _("SMTP authentication password"), :default => nil
    config_option 'messenger.smtp.auth_scheme', _("SMTP authentication scheme"), :default => nil, :type => Symbol,
        :choices => [nil, :plain, :login, :cram_md5]
        
    config_option 'messenger.email.retries', :type => Fixnum, :default => 5
    config_option 'messenger.email.retry_time', _("Seconds to wait until retry (will be incremented at each retry)"), 
        :type => Fixnum, :default => 10
    
end