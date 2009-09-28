module Spider

    config_option 'sso.providers', _("A list of SAML2 providers (SP or IDP)"), :type => :conf
    config_option 'sso.providers.x.name', _("Provider name")
    config_option 'sso.providers.x.role', _("Provider role (idp or sp)"), :type => Symbol, :choices => [:sp, :idp],
        :default => :sp
    config_option 'sso.providers.x.metadata', _("Path to the provider's metadata (defaults to config/sso/metadata/[provider_name].xml)"),
        :default => lambda{ |name| Spider.paths[:config]+'/sso/metadata/'+name+'.xml'}
    config_option 'sso.providers.x.cert_chain', _("Path to the provider's CA certificate chain file (should be in config/sso/cert/[provider_name]_chain.pem)")
    config_option 'sso.providers.x.pub_key', _("Path to the provider's public key (defaults to config/sso/cert/[provider_name].pem)"),
        :default => lambda{ |name| Spider.paths[:config]+'/sso/cert/'+name+'.pem'}

end