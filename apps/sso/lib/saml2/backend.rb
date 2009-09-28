module Spider; module SAML2
    
    # Abstract class implementing the SAML2 methods
    
    class Backend
        
        def self.init(metadata, private_key, certificate)
            return LassoBackend.new(metadata, private_key, certificate)
        end
        
    end
    
    
end; end

require 'apps/sso/lib/saml2/lasso_backend'