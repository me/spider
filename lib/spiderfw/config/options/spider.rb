module Spider

    config_option('runmode', "production, test, devel", :default => 'devel', :choices => ['production', 'test', 'devel'],
        :action => Proc.new{ |option| Spider.runmode = option unless Spider.runmode }
    )
    
    # Storage
    # config_option('storage.type', '')
    # config_option('storage.url', '')
    
    # Web server
    config_option 'http.server', _("The internal server to use"), {
        :default => 'mongrel'
    }
    config_option 'webserver.show_traces', _("Whether to show the stack trace on error"), {
        :default => Proc.new{ ['test', 'devel'].include?(Spider.config.get('runmode')) ? true : false  }
    }
    config_option 'webserver.reload_sources', _("Reload application and spider sources on each request"), {
        :default => Proc.new{ Spider.config.get('runmode') == 'devel' ? true : false }
    }
    config_option 'webserver.port', _("Port to use for the http server"), :default => 8080
    config_option 'webserver.force_threads', _("Force threading on non-threaded adapters"),
        :default => Proc.new{ RUBY_VERSION_PARTS[1] == '8' ? true : false }
    # Client
    config_option 'client.text_editor', _("The text editor installed on the client")
    
    # Templates
    config_option 'template.cache.disable', _("Refresh template cache every time"), { :default => false }
    config_option 'template.safe', _("Run templates in safe mode"), { :default => false }
    
    # Model
    
    config_option 'storage.db.pool.size', _("How many connections to open to a db"), :default => 5
    
    config_option 'storage.db.replace_debug_vars', _("Replace bound variables in debug sql"), {
        :default => Proc.new{ Spider.config.get('runmode') == 'devel' ? true : false }
    }
    
    config_option 'storages', _("A list of named storages"), :type => :conf
    config_option 'storages.x.url', _("Connection url to the storage"), :type => String, :required => true
    config_option 'storages.x.encoding', _("Encoding the DB uses"), :type => String
    
    config_option 'debugger.start', _("Start the debugger")
    
    config_option 'locale', _("The locale to use") do |val|
        Spider.locale = val
    end
 
    config_option 'runner.sleep', _("Sleep time for the periodic runner"), :default => 10
    
    config_option 'session.store', _("Where to store the session"), :default => 'memory', :choices => ['memory', 'file', 'memcached']
    config_option('session.life', _("Lifetime in seconds of the sessions"), :default => 1800, :type => Fixnum)
    config_option('session.purge_check', _("Number of seconds to wait before session purge check"), :default => 10, :type => Fixnum)
    config_option 'session.file.path', _("The folder where to store file sessions"), :default => lambda{ return Spider.paths[:var]+'/sessions' }
    
    config_option 'shared_store.type', _("Which shared store to use"), :default => 'memory'
    
    config_option 'http.nonce_life', _("Life in seconds of HTTP Digest Authentication nonces"), :type => Fixnum, :default => 60
    # TODO: implement in webrick/others, check if has a performance gain
    config_option 'http.auto_headers', _("Automatically send headers on first output (breaks the debugger)"), :default => true
    config_option 'http.seize_stdout', _("Redirect standard output to the browser"), :default => false
    config_option 'http.proxy_mapping', _("If the request is proxyied, the urls used to reach spider, with the corresponding paths called by the proxy"),
        :type => Hash
    
    config_option 'debug.console.level', _("Level of debug output to console"), :default => :INFO,
        :process => lambda{ |opt| opt && opt != 'false' ? opt.upcase.to_sym : false }
    config_option 'log.errors', _("Log errors to file"), :default => true
    config_option 'log.debug.level', _("Log level to use for debug file (false for no debug)"), :default => false,
        :choices => [false, :DEBUG, :INFO],
        :process => lambda{ |opt| opt && opt != 'false' ? opt.upcase.to_sym : false }
#                    :process => lambda{ |v| v.upcase }


    config_option 'orgs', _("A list of organizations"), :type => :conf
    config_option 'orgs.x.name', _("Descriptive name of the organization")
    config_option 'orgs.x.country_code', _("Country code of the organization")
    config_option 'orgs.x.state', _("State of the organization")
    config_option 'orgs.x.city', _("Name of the city")
    config_option 'orgs.x.common_name', _("Common name (e.g. domain) of the organization")
    config_option 'orgs.x.email', _("Main e-mail address of the organization")
    config_option 'orgs.x.organizational_unit', _("Organizational Unit (e.g. department)")
    config_option 'orgs.x.pub_key', _("Path to the public key (defaults to config/certs/org_name/public.pem)"),
        :default => lambda{ |name| Spider.paths[:certs]+'/'+name+'/public.pem'}
    config_option 'orgs.x.cert', _("Path to the certificate (defaults to config/certs/org_name/cert.pem)"),
        :default => lambda{ |name| Spider.paths[:certs]+'/'+name+'/cert.pem'}
    config_option 'orgs.x.private_key', _("Path to the certificate (defaults to config/certs/org_name/private/key.pem)"),
        :default => lambda{ |name| Spider.paths[:certs]+'/'+name+'/private/key.pem'}

    conf_alias 'it_IT' => {
        'orgs' => 'organizzazioni',
        'name' => 'nome',
        'country_code' => 'codice_nazione',
        'city' => 'comune',
        'state' => 'provincia',
        'organizational_unit' => 'unita_organizzativa'
    }
    
    
end
