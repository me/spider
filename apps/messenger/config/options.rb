module Spider
    
    config_option 'messenger.smtp.address', _("SMTP address to use when sending mail"), :default => 'localhost'
    config_option 'messenger.smtp.port', _("SMTP port"), :default => 25
    config_option 'messenger.smtp.domain', _("HELO domain"), :default => 'localhost'
    config_option 'messenger.smtp.username', _("SMTP authentication username"), :default => nil
    config_option 'messenger.smtp.password', _("SMTP authentication password"), :default => nil
    config_option 'messenger.smtp.auth_scheme', _("SMTP authentication scheme"), :default => nil, :type => Symbol,
        :choices => [nil, :plain, :login, :cram_md5]
    config_option 'messenger.smtp.enable_starttls_auto', _("Automatically start TLS for SMTP"), :default => false, :type => Spider::Bool
    config_option 'messenger.smtp.log_path', _("Smtp logfile (e.g. /var/log/mail.log)"), :default => nil
        
    config_option 'messenger.email.retries', _("How many times to retry sending an e-mail"), :type => Fixnum, :default => 5
    config_option 'messenger.email.retry_time', _("Seconds to wait until retry (will be incremented at each retry)"), 
        :type => Fixnum, :default => 10
    config_option 'messenger.queue.run_every', _("Time in seconds between queue runs"), :type => Fixnum, :default => 60
    
    config_option 'messenger.email.backends', _("The backends to use for sending mail (if more than one)"), :type => Array,
        :default => lambda{ Spider.conf.get('messenger.email.backend') ? [Spider.conf.get('messenger.email.backend')] : [] }
    config_option 'messenger.email.backend', _("The backend to use for sending sms"), :type => String, :default => 'smtp'
    
    config_option 'messenger.sms.backends', _("The backends to use for sending sms (if more than one)"), :type => Array,
        :default => lambda{ Spider.conf.get('messenger.sms.backend') ? [Spider.conf.get('messenger.sms.backend')] : [] }
    config_option 'messenger.sms.backend', _("The backend to use for sending sms"), :type => String
    config_option 'messenger.sms.retries', _("How many times to retry sending an sms"), :type => Fixnum, :default => 5
    config_option 'messenger.sms.retry_time', _("Seconds to wait until retry (will be incremented at each retry)"), 
        :type => Fixnum, :default => 10
    config_option 'messenger.smstools.path_spool', _("The path to the smstools 'spool' folder"), :default => '/var/spool/sms'
    config_option 'messenger.smstools.path_outgoing', _("The path to the smstools 'outgoing' folder"), 
        :default => lambda{ File.join(Spider.conf.get('messenger.smstools.path_spool'), 'outgoing')}
    config_option 'messenger.smstools.path_failed', _("The path to the smstools 'failed' folder"), 
        :default => lambda{ File.join(Spider.conf.get('messenger.smstools.path_spool'), 'failed')}    
    config_option 'messenger.smstools.path_sent', _("The path to the smstools 'sent' folder"), 
        :default => lambda{ File.join(Spider.conf.get('messenger.smstools.path_sent'), 'sent')}    
    config_option 'messenger.smstools.remove_failed', _("Whether to remove failed messages from the smstools failed folder"),
        :type => Spider::Bool, :default => true
    config_option 'messenger.smstools.remove_sent', _("Whether to remove failed messages from the smstools sent folder"),
        :type => Spider::Bool, :default => true
    config_option 'messenger.smstools.log_path', _("Smsd logfile"), :default => '/var/log/smsd.log'
    config_option 'messenger.send_immediate', _("Send messages right after the controller action instead of waiting for worker"), 
        :type => Spider::Bool, :default => true
    config_option 'messenger.mobyt.username', _("Username for the Mobyt service"), 
        :type => String    
    config_option 'messenger.mobyt.password', _("Password for the Mobyt service"), 
        :type => String
    config_option 'messenger.mobyt.from', _("From parameter for the Mobyt service"), 
        :type => String
end
