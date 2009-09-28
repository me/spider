require 'apps/sso/lib/saml2/backend'
require 'base64'
require 'uri'
require 'zlib'

module Spider

    module SAML2Mixin
        include Spider::ControllerMixins::HTTPMixin
        
        def self.included(klass)
            klass.extend(ClassMethods)
            super
        end
        
        module ClassMethods
            
            def template_paths
                [Spider::SSO.path+'/views'] + super
            end
        
            def sso_role(*args)
                @sso_roles = {}
                if args.length > 0 
                    args.each { |arg| @sso_roles[arg] = true }
                end
                @sso_roles
            end
        
            def sso_services(*args)
                @sso_services = args if args.length > 0
                @sso_services
            end
        
            def saml2_bindings(*args)
                @saml2_bindings = args if args.length > 0
                @saml2_bindings
            end
        
            def sso_org(val=nil)
                @sso_org = val if val
                @sso_org || 'default'
            end
            
            def sso_id(val=nil)
                @sso_id = val if val
                return @sso_id if @sso_id
                org = Spider.conf.get("orgs.#{sso_org}")
                return org['common_name']
            end
            
        end
        
        def get_metadata(type = :idp)
            @response.headers['Content-Type'] = 'text/xml'
            sso_org = self.class.sso_org
            org = Spider.conf.get("orgs.#{sso_org}")
            raise "Undefined organization #{sso_org}" unless org
            pub_key = org[:pub_key]
            bindings = {}
            self.class.saml2_bindings.each do |b|
                bindings[b] = {}
                self.class.sso_services.each do |s|
                    bindings[b][s] = {
                        :location => request_url + '/'+s.to_s
                    }
                    if b == :http_redirect
                        bindings[b][s][:response_location] = request_url+'/'+s.to_s+'_return'
                    end
                end
            end
            params = {
                :organization => org[:name],
                :key => IO.read(org[:pub_key]),
                :cert => IO.read(org[:cert]),
                :entity_id => self.class.sso_id,
                :bindings => bindings
            }
            return SAML2.metadata(type, params)
        end
        
        def metadata(type = :idp)
            $out << get_metadata(type)
        end
        
        # This method must be implemented by the controller, and has to return the user's attributes
        # to send to the service provider, or raise an Unauthorized exception
        def get_user_attributes
        end
                
        def sso
            saml_request = @request.params['SAMLRequest'] || @request.session[:saml_request]
            @request.session[:saml_request] = saml_request
            raise HTTPStatus.BAD_REQUEST, "SAML Request not found" unless saml_request
            relay_state = @request.params['RelayState'] || @request.session[:saml_relay_state] || ''
            @request.session[:saml_relay_state] = relay_state
            begin
                user = get_user_attributes
            rescue Spider::Auth::Unauthorized
                redir_url = 'login?redirect='+URI.escape(@request.uri)
                redirect(redir_url, Spider::HTTP::FOUND)
            end
            org = Spider.conf.get("orgs.#{self.class.sso_org}")
            @server = SAML2::Backend.init(get_metadata, IO.read(org[:private_key]), IO.read(org[:cert]))
            # decoded_request = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate Base64.decode64 URI.decode saml_request
            #             Spider::Logger.debug("SAML_REQUEST: \n#{decoded_request}")
            #             request = @server.parse_authn_request(decoded_request)
            #             response = @server.authn_response([], @request.session.sid)
            #             @scene.sp_url = request[:assertion_consumer_url]
            #             @scene.saml_response = response[:body]
            #             @scene.relay_state = relay_state
            #             @response.headers['Content-Type'] = 'text/html'
            #             render('saml2_post')
            request = @server.parse_authn_request(@request.env['QUERY_STRING'])
            response = @server.authn_response([], @request.session.sid)
            @request.session.delete(:saml_request)
            @request.session.delete(:saml_relay_state)
            @scene.sp_url = response[:url]
            @scene.saml_response = response[:body]
            @scene.relay_state = relay_state
            send_saml_response(response)
            
        end
        
        def single_logout
            saml_request = @request.params['SAMLRequest']
            raise HTTPStatus.BAD_REQUEST, "SAML Request not found" unless saml_request
            org = Spider.conf.get("orgs.#{self.class.sso_org}")
            @server = SAML2::Backend.init(get_metadata, IO.read(org[:private_key]), IO.read(org[:cert]))
            request = @server.parse_logout_request(@request.env['QUERY_STRING'])
            @request.session.class.delete(request[:session_index])
            response = @server.logout_response
            send_saml_response(response)
        end
        
        def send_saml_response(response)
            if (response[:body])
                # Always respond through POST, is this correct ?
                @response.headers['Content-Type'] = 'text/html'
                render('saml2_post')
            else
                redirect(response[:url], Spider::HTTP::FOUND)
            end
        end
        
    end
    
    
end