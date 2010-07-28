require 'apps/cas_server/lib/cas'
require 'builder'
require 'rexml/document'
require "uuidtools"

module Spider; module CASServer

    module CASLoginMixin
        include Annotations
        include Spider::CASServer::CAS
        
        CAS_NS                  = 'http://www.yale.edu/tp/cas'
        SOAP_ENVELOPE_NS        = 'http://schemas.xmlsoap.org/soap/envelope/'
        SAML1_NS                = 'urn:oasis:names:tc:SAML:1.0:protocol'
        SAML1_ASSERTION_NS      = 'urn:oasis:names:tc:SAML:1.0:assertion'
        XML_SCHEMA_NS           = 'http://www.w3.org/2001/XMLSchema'
        XML_SCHEMA_INSTANCE_NS  = 'http://www.w3.org/2001/XMLSchema-instance'
        SAML1_ARTIFACT          = 'urn:oasis:names:tc:SAML:1.0:cm:artifact'
        CAS_OPENWEB_NS          = 'http://mapweb.it/openweb/cas'
        SAML1_PASSWORD          = 'urn:oasis:names:tc:SAML:1.0:am:password'

        def self.included(controller)
            controller.route 'proxyValidate', :proxy_validate
            controller.route 'serviceValidate', :service_validate
            controller.route 'samlValidate', :saml_validate
            #controller.route 'login', :index
        end

        def before(action='', *arguments)
            is_saml = false
            if @request.params['service']
                @service = clean_service_url(@request.params['service'])
            elsif Spider.conf.get('cas.saml1_1_compatible') && @request.params['TARGET']
                @service = clean_service_url(@request.params['TARGET'])
                is_saml = true
            end
            @renew = @request.params['renew']
            @gateway = @request.params['gateway'] == 'true' || @request.params['gateway'] == '1'
            if tgc = @request.cookies['tgc']
                tgt, tgt_error = validate_ticket_granting_ticket(tgc)
            end
            if tgt and !tgt_error
                @scene.cas_message = {
                    :type => 'notice', 
                    :message => _(%{You are currently logged in as "#{tgt.username}". If this is not you, please log in below.})
                }
            end
            if @request.params['redirection_loop_intercepted']
                @scene.cas_message = {
                    :type => 'mistake', 
                    :message => _(%{The client and server are unable to negotiate authentication. Please try logging in again later.})
                }
            end
            begin
                if @service #&& cas_service_allowed?(@service)
                    if !@renew && tgt && !tgt_error
                        st = generate_service_ticket(@service, tgt.username, tgt)
                        service_with_ticket = service_uri_with_ticket(@service, st, is_saml)
                        $LOG.info("User '#{tgt.username}' authenticated based on ticket granting cookie. Redirecting to service '#{@service}'.")
                        return redirect(service_with_ticket, 303) # response code 303 means "See Other" (see Appendix B in CAS Protocol spec)
                    elsif @gateway
                        $LOG.info("Redirecting unauthenticated gateway request to service '#{@service}'.")
                        return redirect(@service, 303)
                    end
                elsif @gateway
                    $LOG.error("This is a gateway request but no service parameter was given!")
                    @scene.cas_message = {
                        :type => 'mistake', 
                        :message => _("The server cannot fulfill this gateway request because no service parameter was given.")
                    }
                end
            rescue URI::InvalidURIError
                $LOG.error("The service '#{@service}' is not a valid URI!")
                @scene.cas_message = {
                    :type => 'mistake', 
                    :message => _("The target service your browser supplied appears to be invalid. Please contact your system administrator for help.")
                }
            end
            @scene.cas_service = @service
            super
        end

        def response_xml
            xm = Builder::XmlMarkup.new(:target => $out, :indent => 2)
            #xm.instruct!
            return xm
        end

        def cas_user_attributes(user)
            return user.user_attributes(:cas) if user.respond_to?(:user_attributes)
            return {}
        end

        def cas_service_allowed?(service, user)
            return true
        end

        def authenticate
            if error = validate_login_ticket(@request.params['lt'])
                @scene.message = error
                return nil
            end
            user = super
            return nil unless user
            if @service && !@service.empty? && !cas_service_allowed?(@service, user)
                @scene.message = {:type => 'error', :message => _("The user is not allowed to acces this service.")}
                return nil
            end
            cas_user_authenticated(user)
            return user
        end

        def cas_user_authenticated(user)
            extra_attributes = cas_user_attributes(user)
            tgt = generate_ticket_granting_ticket(user.identifier, extra_attributes)
            if Spider.conf.get('cas.expire_sessions')
                expires = Time.now + Spider.conf.get('cas.ticket_granting_ticket_expiry')
                expiry_info = " It will expire on #{expires}."
            else
                expiry_info = " It will not expire."
            end
            if Spider.conf.get('cas.expire_sessions')
                @response.cookies['tgt'] = {
                    :value => tgt.to_s, 
                    :expires => Time.now + Spider.conf.get('cas.ticket_granting_ticket_expiry')
                }
            else
                @response.cookies['tgt'] = tgt.to_s
            end
            $LOG.debug("Ticket granting cookie '#{@response.cookies[:tgt].inspect}' granted to '#{user.identifier.inspect}'. #{expiry_info}")
            if @service.nil? || @service.empty?
                $LOG.info("Successfully authenticated user '#{user.identifier}' at '#{tgt.client_hostname}'. No service param was given, so we will not redirect.")
                @scene.cas_message = {:type => 'confirmation', :message => _("You have successfully logged in.")}
            else
                @st = generate_service_ticket(@service, user.identifier, tgt)
                begin
                    service_with_ticket = service_uri_with_ticket(@service, @st)

                    $LOG.info("Redirecting authenticated user '#{user.identifier}' at '#{@st.client_hostname}' to service '#{@service}'")
                    resp_code = Spider.conf.get('cas.saml1_1_compatible') ? 302 : 303
                    return redirect(service_with_ticket, resp_code) # response code 303 means "See Other" (see Appendix B in CAS Protocol spec)
                rescue URI::InvalidURIError
                    $LOG.error("The service '#{@service}' is not a valid URI!")
                    @message = {:type => 'mistake', :message => _("The target service your browser supplied appears to be invalid. Please contact your system administrator for help.")}
                end
            end
        end

        __.html
        def login
            @service = clean_service_url(@request.params['service'] || @request.params['destination'])
            if @request.user && !@request.params.key?('renew')
                if !@service || @service.empty? || cas_service_allowed?(@service, @request.user)
                    return cas_user_authenticated(@request.user)
                else
                    raise Forbidden
                end
            end 
            index
        end

        __.html
        def logout
            @service = clean_service_url(@request.params['service'] || @request.params['destination'])
            @gateway = @request.params['gateway'] == 'true' || @request.params['gateway'] == '1'
            tgt = TicketGrantingTicket.load(:ticket => @request.cookies['tgt'])
            @response.cookies.delete('tgt') # FIXME
            if tgt
                TicketGrantingTicket.transaction do
                    pgts = ProxyGrantingTicket.where('service_ticket.username' => tgt.username)
                    pgts.each do |pgt|
                        pgt.delete
                    end
                    if Spider.conf.get('cas_enable_single_sign_out')
                        $LOG.debug("Deleting Service/Proxy Tickets for '#{tgt}' for user '#{tgt.username}'")
                        tgt.service_tickets.each do |st|
                            send_logout_notification_for_service_ticket(st)
                            # TODO: Maybe we should do some special handling if send_logout_notification_for_service_ticket fails? 
                            #       (the above method returns false if the POST results in a non-200 HTTP response).
                            $LOG.debug "Deleting #{st.class.name} #{st.ticket.inspect}."
                            st.delete
                        end
                    end
                    $LOG.debug("Deleting #{tgt.class.name} '#{tgt}' for user '#{tgt.username}'")
                    tgt.delete

                    if Spider.conf.get('cas.enable_single_sign_out')
                        $LOG.debug("Deleting Service/Proxy Tickets for '#{tgt}' for user '#{tgt.username}'")
                        tgt.service_tickets.each do |st|
                            send_logout_notification_for_service_ticket(st)
                            # TODO: Maybe we should do some special handling if send_logout_notification_for_service_ticket fails? 
                            #       (the above method returns false if the POST results in a non-200 HTTP response).
                            $LOG.debug "Deleting #{st.class.name} #{st.ticket.inspect}."
                            st.delete
                        end
                    end

                    $LOG.debug("Deleting #{tgt.class.name} '#{tgt}' for user '#{tgt.username}'")
                    tgt.delete
                end  

                $LOG.info("User '#{tgt.username}' logged out.")
            else
                $LOG.warn("User tried to log out without a valid ticket-granting ticket")
            end
            @scene.cas_message = {:type => 'confirmation', :message => _("You have successfully logged out.")}
            @scene.cas_message[:message] << _(" Please click on the following link to continue:") if @continue_url
            @scene.continue_url = @continue_url
            if (@gateway && @service)
                redirect(@service, 303)
            elsif (@continue_url)
                render 'logout'
            else
                render 'login'
            end
        end

        def validate
            @service = clean_service_url(@request.params['service'])
            @ticket = @request.params['ticket']
            # optional
            @renew = @request.params['renew']

            st, @error = validate_service_ticket(@service, @ticket)      
            @success = st && !@error

            @username = st.username if @success

            @response.status = response_status_from_error(@error) if @error
            if (@success)
                $out << "yes\n#{@username}\n"
            else
                $out << "no\n\n"
            end

        end
        
        __.xml
        def saml_validate
            @error = nil
            @success = false
            begin
                req = @request.read_body
                doc = REXML::Document.new req
            rescue REXML::ParseException
                raise CASSAMLError, "Could not parse XML"
            end
            client_hostname = @request.env['HTTP_X_FORWARDED_FOR'] || @request.env['REMOTE_HOST'] || @request.env['REMOTE_ADDR']
            raise CASSAMLError, "SOAP Envelope not found" unless doc.root && doc.root.name == 'Envelope' && doc.root.namespace == SOAP_ENVELOPE_NS
            @service = clean_service_url(@request.params['service'] || @request.params['TARGET'])
            @service = nil if @service.blank?
            ns = {'SOAP-ENV' => SOAP_ENVELOPE_NS, 'samlp' => SAML1_NS }
            body = REXML::XPath.first(doc, "//SOAP-ENV:Body", ns)
            raise CASSAMLError, "SOAP Body not found" unless body
            request = REXML::XPath.first(body, "//samlp:Request", ns)
            raise CASSAMLError, "SAML Request not found" unless request
            unless request.attributes["MajorVersion"] == '1' && request.attributes['MinorVersion'] == '1'
                raise CASSAMLError, "CAS requires SAML version 1.1" 
            end
            artifact = REXML::XPath.first(body, "//samlp:AssertionArtifact", ns)
            raise CASSAMLError, "SAML AssertionArtifact not found" unless artifact
            @ticket = artifact.text.strip
            st, @error = validate_service_ticket(@service, @ticket, false, true)
            @success = st && !@error
            
            raise CASSAMLError, "Error validating the service ticket: #{@error}" unless @success
            
            if @success
                @username = st.username  
                @extra_attributes = st.ticket_granting_ticket.extra_attributes || {}
            end
            now = Time.now
            @response.headers['Content-Type'] = 'text/xml'
            xm = Builder::XmlMarkup.new(:target => $out, :indent => 2)
            xm.instruct!
            xm.tag!("SOAP-ENV", :Envelope, 'xmlns:SOAP-ENV' => SOAP_ENVELOPE_NS) do
                xm.tag!("SOAP-ENV", :Header)
                xm.tag!("SOAP-ENV", :Body){
                    xm.Response(
                        'xmlns' => SAML1_NS,
                        'xmlns:saml' => SAML1_ASSERTION_NS,
                        'xmlns:samlp' => SAML1_NS,
                        'xmlns:xsd' => XML_SCHEMA_NS,
                        'xmlns:xsi' => XML_SCHEMA_INSTANCE_NS,
                        'IssueInstant' => now.xmlschema,
                        'MajorVersion' => '1',
                        'MinorVersion' => '1',
                        'Recipient' => client_hostname,
                        'ResponseID' => '_'+UUIDTools::UUID.random_create.hexdigest
                    ){
                        xm.Status{
                            xm.StatusCode('Value' => 'samlp:Success')
                        }
                        xm.Assertion(
                            'xmlns' => SAML1_ASSERTION_NS,
                            'AssertionID' => '_'+UUIDTools::UUID.random_create.hexdigest,
                            'IssueInstant' => now.xmlschema,
                            'Issuer' => @request.http_host,
                            'MajorVersion' => '1',
                            'MinorVersion' => '1'
                        ){
                            xm.Conditions('NotBefore' => now.xmlschema, 'NotOnOrAfter' => (now+Spider.conf.get('cas.service_ticket_expiry')).xmlschema){
                                xm.AudienceRestrictionCondition{
                                    xm.Audience client_hostname
                                }
                            }
                            xm.AttributeStatement{
                                xm.Subject{
                                    xm.NameIdentifier @username.to_s
                                }
                                xm.SubjectConfirmation{
                                    xm.ConfirmationMethod SAML1_ARTIFACT
                                }
                                @extra_attributes.each do |key, value|
                                    xm.Attribute('AttributeName' => key.to_s, 'AttributeNamespace' => CAS_OPENWEB_NS){
                                        if value.kind_of?(String) || value.kind_of?(Numeric)
                                            xm.AttributeValue value
                                        else
                                            xm.AttributeValue{ xm.cdata!(value.to_yaml) }
                                        end
                                    }

                                end
                            }
                            xm.AuthenticationStatement(
                                'AuthenticationInstant' => now.xmlschema,
                                'AuthenticationMethod' => SAML1_PASSWORD
                            ){
                                xm.Subject{
                                    xm.NameIdentifier @username.to_s
                                }
                                xm.SubjectConfirmation{
                                    xm.ConfirmationMethod SAML1_ARTIFACT
                                }
                            }
                        }
                        
                    }
                }
            end
            
            
        end

        def service_validate

            # required
            @service = clean_service_url(@request.params['service'])
            @ticket = @request.params['ticket']
            # optional
            @pgt_url = @request.params['pgtUrl']
            @renew = @request.params['renew']

            st, @error = validate_service_ticket(@service, @ticket)      
            @success = st && !@error

            if @success
                @username = st.username  
                if @pgt_url
                    pgt = generate_proxy_granting_ticket(@pgt_url, st)
                    @pgtiou = pgt.iou if pgt
                end
                @extra_attributes = st.ticket_granting_ticket.extra_attributes || {}
            end

            @response.status = response_status_from_error(@error) if @error

            xm = response_xml
            xm.cas(:serviceResponse, 'xmlns:cas' => CAS_NS, 'xmlns:ow' => CAS_OPENWEB_NS) do
                if (@success)
                    xm.cas(:authenticationSuccess) do
                        xm.cas(:user, @username.to_s)
                        @extra_attributes.each do |key, value|
                            if value.kind_of?(String) || value.kind_of?(Numeric)
                                xm.tag!(:ow, key.to_s.to_sym, value)
                            else
                                xm.tag!(:ow, key.to_s.to_sym){ xm.cdata!(value.to_yaml) }
                            end
                        end
                        if (@pgtiou)
                            xm.cas(:proxyGrantingTicket, @pgtiou.to_s)
                        end
                    end
                else
                    xm.cas(:authenticationFailure, :code => @error.code){ xm.text!(@error.to_s) }
                end
            end
        end

        __.xml
        def proxy_validate

            # required
            @service = clean_service_url(@request.params['service'])
            @ticket = @request.params['ticket']
            # optional
            @pgt_url = @request.params['pgtUrl']
            @renew = @request.params['renew']

            @proxies = []
            t, @error = validate_proxy_ticket(@service, @ticket)      
            @success = t && !@error

            @extra_attributes = {}
            if @success
                @username = t.username

                if t.is_a? ProxyTicket
                    @proxies << t.proxy_granting_ticket.service_ticket.service
                end

                if @pgt_url
                    pgt = generate_proxy_granting_ticket(@pgt_url, t)
                    @pgtiou = pgt.iou if pgt
                end

                @extra_attributes = t.ticket_granting_ticket.extra_attributes || {}
            end

            Spider::Logger.error(@error) if @error
            @response.status = response_status_from_error(@error) if @error
            xm = response_xml
            xm.cas(:serviceResponse, 'xmlns:cas' => 'http://www.yale.edu/tp/cas') do
                if (@success)
                    xm.cas(:authenticationSuccess) do
                        xm.cas(:user, @username.to_s)
                        @extra_attributes.each do |key, value|
                            if value.kind_of?(String) || value.kind_of?(Numeric)
                                xm.tag!(key.to_s, value)
                            else
                                xm.tag!(key.to_s){ xm.cdata!(value.to_yaml) }
                            end
                        end
                        if (@pgtiou)
                            xm.cas(:proxyGrantingTicket, @pgtiou.to_s)
                        end
                        if (@proxies && !@proxies.empty?)
                            xm.cas(:proxies) do
                                @proxies.each do |proxy_url|
                                    xm.cas(:proxy, proxy_url.to_s)
                                end
                            end
                        end
                    end
                else
                    xm.cas(:authenticationFailure, :code => @error.code){ xm.text!(@error.to_s) }
                end
            end
        end


        __.xml
        def proxy

            # required
            @ticket = @request.params['pgt']
            @target_service = @request.params['targetService']

            pgt, @error = validate_proxy_granting_ticket(@ticket)
            @success = pgt && !@error

            if @success
                @pt = generate_proxy_ticket(@target_service, pgt)
            end

            @response.status = response_status_from_error(@error) if @error

            xm = response_xml
            xm.cas(:serviceResponse, 'xmlns:cas' => 'http://www.yale.edu/tp/cas') do
                if (@success)
                    xm.cas(:proxySuccess) do
                        xm.cas(:proxyTicket, @pt.to_s)
                    end
                else
                    xm.cas(:proxyFailure, :code => @error.code){ xm.text!(@error.to_s) }
                end
            end
        end

        def response_status_from_error(error)
            case error.code.to_s
            when /^INVALID_/, 'BAD_PGT'
                422
            when 'INTERNAL_ERROR'
                500
            else
                500
            end
        end
        
        def try_rescue(exc)
            if exc.is_a?(CASSAMLError)
                @response.headers['Content-Type'] = 'text/xml'
                now = Time.now
                xm = Builder::XmlMarkup.new(:target => $out, :indent => 2)
                xm.instruct!
                xm.tag!("SOAP-ENV", :Envelope, 'xmlns:SOAP-ENV' => SOAP_ENVELOPE_NS) do
                    xm.tag!("SOAP-ENV", :Header)
                    xm.tag!("SOAP-ENV", :Body){
                        xm.Response(
                            'xmlns' => SAML1_NS,
                            'xmlns:saml' => SAML1_ASSERTION_NS,
                            'xmlns:samlp' => SAML1_NS,
                            'xmlns:xsd' => XML_SCHEMA_NS,
                            'xmlns:xsi' => XML_SCHEMA_INSTANCE_NS,
                            'IssueInstant' => now.xmlschema,
                            'MajorVersion' => '1',
                            'MinorVersion' => '1',
                            'Recipient' => @request.env['HTTP_REFERER'],
                            'ResponseID' => '_'+UUIDTools::UUID.random_create.hexdigest
                        ){
                            xm.Status{
                                xm.StatusCode('Value' => 'samlp:Failure')
                                xm.StatusMessage(exc.message)
                            }
                        }
                    }
                end
                done
            end
            super
        end

    end

    class CASSAMLError < RuntimeError
    end

end; end
