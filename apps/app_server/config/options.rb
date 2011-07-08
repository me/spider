Spider.config_option 'app_server.url', _("Url of the app server"), :default => 'http://www.soluzionipa.it/euroservizi/spider/app_server'
Spider.config_option 'app_server.search_paths', _("Paths to search for apps"), :type => Array
Spider.config_option 'app_server.git_ssh', _("Name of the ssh server")
Spider.config_option 'app_server.git_http', _("Http git prefix for each git path"), :type => Hash
Spider.config_option 'app_server.git_repo_base', _("Base path for read-only git repository access")
Spider.config_option 'app_server.git_repo_rw_base', _("Base path for read-write git repository access")
