require 'builder'

module Spider

    module SAML2
        MetadataNs = 'urn:oasis:names:tc:SAML:2.0:metadata'
        AssertionNs = 'urn:oasis:names:tc:SAML:2.0:assertion'
        ProtocolNs = 'urn:oasis:names:tc:SAML:2.0:protocol'
        XMLDsNs = 'http://www.w3.org/2000/09/xmldsig#'
        AttributeFormats = {
            :unspecified => 'urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified',
            :uri => 'urn:oasis:names:tc:SAML:2.0:attrname-format:uri',
            :basic => 'urn:oasis:names:tc:SAML:2.0:attrname-format:basic'
        }
        
        def self.services
            {
                :artifact_resolution => 'ArtifactResolution',
                :single_logout => 'SingleLogout',
                :manage_name_id => 'ManageNameID',
                :sso => 'SingleSignOn'
            }
        end
        
        def self.bindings
            {
                :soap => 'urn:oasis:names:tc:SAML:2.0:bindings:SOAP',
                :http_redirect => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect'
            }
        end

        def self.idp_metadata(params)
            return metadata(:idp, params)
        end
        
        def self.sp_metadata(params)
            return metadata(:sp, params)
        end

        def self.metadata(type, params)
            defaults = {
            }
            if type == :idp
                defaults.merge!({
                    :authn_request_signed => 'true'
                })
            elsif type == :sp
                defaults.merge!({
                    :want_authn_request_signed => 'true'
                })
            end
            params.reject!{ |k, v| !v }
            params.merge!(defaults)
            xml = ''
            xm = Builder::XmlMarkup.new(:target => xml, :indent => 2)
            xm.instruct!
            xm.EntityDescriptor(
                'xmlns' => MetadataNs,
                'xmlns:saml' => AssertionNs,
                'xmlns:ds' => XMLDsNs,
                'entityID' => params[:entity_id]
            ) do
                descriptor_name = type == :sp ? :SPSSODescriptor : :IDPSSODescriptor
                xm.method_missing(descriptor_name,
                    'WantAuthnRequestsSigned' => params[:want_authn_request_signed],
                    'AuthnRequestSigned' => params[:authn_request_signed],
                    'protocolSupportEnumeration' => ProtocolNs
                ) do
                    xm.KeyDescriptor('use' => 'signing') do
                        xm.ds(:KeyInfo, 'xmlns:ds' => XMLDsNs) do
                            xm.ds(:X509Data) do
                                xm.ds(:X509Certificate, params[:cert])
                            end
                        end
                    end
                    xm.KeyDescriptor('use' => 'encryption') do
                        xm.ds(:KeyInfo, 'xmlns:ds' => XMLDsNs) do
                            xm.ds(:KeyValue, params[:key])
                        end
                    end
                    params[:bindings].each do |binding, services|
                        binding_ns = self.bindings[binding]
                        services.each do |name, data|
                            service_name = self.services[name]+'Service'
                            attributes = {}
                            attributes['Binding'] = binding_ns
                            attributes['Location'] = data[:location] if data[:location]
                            attributes['ResponseLocation'] = data[:response_location] if data[:response_location]
                            xm.method_missing(service_name, attributes)
                        end
                    end
                end
                xm.Organization do
                    xm.OrganizationName(params[:organization], 'xml:lang' => 'en')
                end
            end
            return xml
        end
        
        def self.load_metadata(provider)
            providers = Spider.conf.get('sso.providers')
            return IO.read(providers[provider]['metadata'])
        end
        
        
        class SAML2Exception < RuntimeError
        end

    end


end