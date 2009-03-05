module Spider

    config_option('runmode', "production, test, devel", :default => 'devel', :choices => ['production', 'test', 'devel'],
        :action => Proc.new do |option|
            Spider.configuration.include_set(option)
            case option
            when 'devel' || 'test'
                require 'ruby-debug'
            end
        end
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
    # Client
    config_option 'client.text_editor', _("The text editor installed on the client")
    
    # Templates
    config_option 'template.cache.disable', _("Refresh template cache every time"), { :default => false }
    
    # Model
    
    config_option 'storages', _("A list of named storages"), {:type => Hash}
    
    config_option 'debugger.start', _("Start the debugger")
    
    config_option 'locale', _("The locale to use")
 
    config_option 'runner.sleep', _("Sleep time for the periodic runner"), :default => 10
    
    config_option 'session.store', _("Where to store the session"), :default => 'memory', :choices => ['memory', 'file', 'memcached']
    config_option('session.life', _("Lifetime in seconds of the sessions"), :default => 1800, :type => Fixnum)
    config_option('session.purge_check', _("Number of seconds to wait before session purge check"), :default => 10, :type => Fixnum)
    config_option 'session.file.path', _("The folder where to store file sessions"), :default => lambda{ return Spider.paths[:var]+'/sessions' }
    
    config_option 'shared_store.type', _("Which shared store to use"), :default => 'memory'
    
    config_option 'http.nonce_life', _("Life in seconds of HTTP Digest Authentication nonces"), :type => Fixnum, :default => 60
end