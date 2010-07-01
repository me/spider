module Spider

    config_option('runmode', "production, test, devel", :default => 'devel', :choices => ['production', 'test', 'devel'],
        :action => Proc.new{ |option| Spider.runmode = option unless Spider.runmode || $SPIDER_RUNMODE}
    )
    
    # Storage
    # config_option('storage.type', '')
    # config_option('storage.url', '')
    
    # Web server
    config_option 'http.server', _("The internal server to use"), {
        :default => lambda{
            begin
                require 'rubygems'
                require 'mongrel'
                'mongrel'
            rescue LoadError
                'webrick'
            end
        },
        :type => String, :choices => ['webrick', 'mongrel', 'thin']
    }
    config_option 'webserver.show_traces', _("Whether to show the stack trace on error"), {
        :default => Proc.new{ ['test', 'devel'].include?(Spider.config.get('runmode')) ? true : false  }
    }
    config_option 'webserver.reload_sources', _("Reload application and spider sources on each request"), {
        :default => Proc.new{ Spider.config.get('runmode') == 'devel' ? true : false }
    }
    config_option 'webserver.port', _("Port to use for the http server"), :type => Fixnum, :default => 8080
    config_option 'webserver.force_threads', _("Force threading on non-threaded adapters"),
        :default => Proc.new{ RUBY_VERSION_PARTS[1] == '8' ? true : false }
    config_option 'webserver.timeout', _("Time allowed for each request (in seconds)"), :type=> Fixnum, :default => nil
    config_option 'static_content.mode', _("Mode to use for serving static files"), :type => String,
        :choices => [nil, 'x-sendfile', 'x-accel-redirect', 'published'], :default => nil
    config_option 'static_content.auto_publish', _("Automatically publish content to the home's public folder"),
        :type => Spider::DataTypes::Bool, :default => false
    # Client
    config_option 'client.text_editor', _("The text editor installed on the client")
    
    # Templates
    config_option 'template.cache.disable', _("Refresh template cache every time"), { :default => false }
    config_option 'template.cache.reload_on_restart', _("Refresh template cache when server restarts"), { :default => true }
    config_option 'template.cache.no_check', _("Never recompile templates"), { :default => true }
    config_option 'template.cache.check_files', _("Check on every request if templates are changed"), { :default => true }
    
    
    #config_option 'template.safe', _("Run templates in safe mode"), { :default => false }
    
    # Model
    
    config_option 'storage.db.pool.size', _("How many connections to open to a db"), :default => 5
    config_option 'storage.db.pool.timeout', _("Timout in seconds to obtain a connection"), :default => 5
    config_option 'storage.db.pool.retry', _("How many times to retry acquiring a connection"), :default => 5
    
    config_option 'storage.db.replace_debug_vars', _("Replace bound variables in debug sql"), {
        :default => Proc.new{ Spider.config.get('runmode') == 'devel' ? true : false }
    }
    
    config_option 'storages', _("A list of named storages"), :type => :conf
    config_option 'storages.x.url', _("Connection url to the storage"), :type => String, :required => true
    config_option 'storages.x.encoding', _("Encoding the DB uses"), :type => String
    config_option 'storages.x.enable_transactions', _("Whether to enable transactions on the db"), :type => Spider::DataTypes::Bool, :default => true
    
    config_option 'debugger.start', _("Start the debugger")
    config_option 'profiling.enable', _("Enable on-request profiling")
    config_option 'request.mutex', _("Respond to requests sequentially"), :default => false
    
    config_option 'locale', _("The locale to use") do |val|
        Spider.locale = Locale.new(val)
    end
    config_option 'i18n.rails_path', _("Path where rails-style locales are found"), :default => lambda{ Spider.paths[:root]+'/locales' }
    config_option 'i18n.default_locale', _("Fallback locale"), :default => 'en'
 
    config_option 'runner.sleep', _("Sleep time for the periodic runner"), :default => 10
    
    config_option 'session.store', _("Where to store the session"), :default => 'file', :choices => ['memory', 'file', 'memcached']
    config_option('session.life', _("Lifetime in seconds of the sessions"), :default => 3600, :type => Fixnum)
    config_option('session.purge_check', _("Number of seconds to wait before session purge check"), :default => 10, :type => Fixnum)
    config_option 'session.file.path', _("The folder where to store file sessions"), :default => lambda{ return Spider.paths[:var]+'/sessions' }
    
    config_option 'shared_store.type', _("Which shared store to use"), :default => 'memory'
    
    config_option 'http.nonce_life', _("Life in seconds of HTTP Digest Authentication nonces"), :type => Fixnum, :default => 60
    # TODO: implement in webrick/others, check if has a performance gain
    config_option 'http.auto_headers', _("Automatically send headers on first output"), 
        :type => Spider::DataTypes::Bool, :default => true
    config_option 'http.seize_stdout', _("Redirect standard output to the browser"), :default => false
    config_option 'http.proxy_mapping', _("If the request is proxyied, the urls used to reach spider, with the corresponding paths called by the proxy"),
        :type => Hash
    config_option 'http.charset', _("The charset to use for http requests"), :default => 'UTF-8'
    
    config_option 'debug.console.level', _("Level of debug output to console"), :default => :INFO,
        :process => lambda{ |opt| opt && opt != 'false' ? opt.to_s.upcase.to_sym : false },
        :choices => [false, :DEBUG, :WARN, :INFO, :ERROR]
    config_option 'log.errors', _("Log errors to file"), :type => Spider::DataTypes::Bool, :default => true
    config_option 'log.debug.level', _("Log level to use for debug file (false for no debug)"), :default => false,
        :choices => [false, :DEBUG, :WARN, :INFO, :ERROR],
        :process => lambda{ |opt| opt && opt != 'false' ? opt.to_s.upcase.to_sym : false }
    config_option 'log.rotate.age', _("Number of old log files to keep, OR frequency of rotation (daily, weekly or monthly)"), :default => 'daily'
    config_option 'log.rotate.size', _("Maximum logfile size (only applies when log.rotate.age is a number)"), :default => 1048576


    config_option 'orgs', _("A list of organizations"), :type => :conf
    config_option 'orgs.x.name', _("Descriptive name of the organization")
    config_option 'orgs.x.country_code', _("Country code of the organization")
    config_option 'orgs.x.state', _("State of the organization")
    config_option 'orgs.x.city', _("Name of the city")
    config_option 'orgs.x.common_name', _("Common name (e.g. domain) of the organization")
    config_option 'orgs.x.email', _("Main e-mail address of the organization")
    config_option 'orgs.x.auto_from_email', _("Email address used as 'From' for automatic e-mails"),
        :default => lambda{ |name| Spider.conf.get("orgs.#{name}.email") }
    config_option 'orgs.x.organizational_unit', _("Organizational Unit (e.g. department)")
    config_option 'orgs.x.pub_key', _("Path to the public key (defaults to config/certs/org_name/public.pem)"),
        :default => lambda{ |name| Spider.paths[:certs]+'/'+name+'/public.pem'}
    config_option 'orgs.x.cert', _("Path to the certificate (defaults to config/certs/org_name/cert.pem)"),
        :default => lambda{ |name| Spider.paths[:certs]+'/'+name+'/cert.pem'}
    config_option 'orgs.x.private_key', _("Path to the private key (defaults to config/certs/org_name/private/key.pem)"),
        :default => lambda{ |name| Spider.paths[:certs]+'/'+name+'/private/key.pem'}

    conf_alias 'it_IT' => {
        'orgs' => 'organizzazioni',
        'name' => 'nome',
        'country_code' => 'codice_nazione',
        'city' => 'comune',
        'state' => 'provincia',
        'organizational_unit' => 'unita_organizzativa'
    }
    
    config_option 'site.admin.name', _("Name of the site administrator")
    config_option 'site.admin.email', _("Email of the site administrator")
    config_option 'site.tech_admin.email', _("Email of the site technical administrator"), 
        :default => lambda{ Spider.conf.get('site.admin.email') }
       
        
    config_option 'errors.send_email', _("Send an e-mail to the technical administrator when errors occur"), :type => Spider::DataTypes::Bool,
         :default => lambda{ Spider.config.get('runmode') == 'production' ? true : false }
    
    config_option 'devel.trace.extended', _("Use ruby-debug to provide extended traces"), :default => true
    config_option 'devel.trace.show_locals', _("Show locals in debug traces"), :default => true
    config_option 'devel.trace.show_instance_variables', _("Show locals in debug traces"), :default => true
    
    config_option 'javascript.compress', _("Compress JavaScript files"), 
        :default => lambda{ Spider.config.get('runmode') == 'production' ? true : false }
    config_option 'css.compress', _("Combine CSS files"), 
        :default => lambda{ Spider.config.get('runmode') == 'production' ? true : false }
    config_option 'css.cachebuster', _("Use cache busters for CSS urls"), :type => Symbol,
        :default => :soft, :choices => [false, :soft, :hard, :hardcopy]
    
    
end
