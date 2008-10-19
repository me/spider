module Spider
    include Configurable

    config_option('runmode', "production, test, devel", :default => 'devel', :choices => ['production', 'test', 'devel'],
        :action => Proc.new do |option|
            config_include_set(option)
            case option
            when 'devel' || 'test'
                require 'ruby-debug'
            end
        end
    )
    config_option('storage.type', '')
    config_option('storage.url', '')
    config_option 'http.server', _("The internal server to use"), {
        :default => 'mongrel'
    }
    config_option 'webserver.show_traces', _("Whether to show the stack trace on error"), {
        :default => Proc.new{ ['test', 'devel'].include?(Spider.config.get('runmode')) ? true : false  }
    }
    config_option 'webserver.reload_sources', _("Reload application and spider sources on each request"), {
        :default => Proc.new{ Spider.config.get('runmode') == 'devel' ? true : false }
    }
    config_option 'client.text_editor', _("The text editor installed on the client")
    
end