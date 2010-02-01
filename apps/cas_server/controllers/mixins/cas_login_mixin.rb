require 'apps/cas_server/lib/cas'
require 'builder'

module Spider; module CASServer

    module CASLoginMixin
        include Annotations
        include Spider::CASServer::CAS
        
        def self.included(controller)
            controller.route 'proxyValidate', :proxy_validate
            controller.route 'serviceValidate', :service_validate
            controller.route 'login', :index
        end

        def before(action='', *arguments)
            @service = clean_service_url(@request.params['service'])
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
                if @service
                    if !@renew && tgt && !tgt_error
                        st = generate_service_ticket(@service, tgt.username, tgt)
                        service_with_ticket = service_uri_with_ticket(@service, st)
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
        
        def authenticate
            if error = validate_login_ticket(@request.params['lt'])
                @scene.message = error
                return nil
            end
            user = super
            return nil unless user
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
                    return redirect(service_with_ticket, 303) # response code 303 means "See Other" (see Appendix B in CAS Protocol spec)
                rescue URI::InvalidURIError
                    $LOG.error("The service '#{@service}' is not a valid URI!")
                    @message = {:type => 'mistake', :message => _("The target service your browser supplied appears to be invalid. Please contact your system administrator for help.")}
                end
            end
        end
        
        __.html
        def login
            if (@request.user)
                return cas_user_authenticated(@request.user)
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

    end

end; end
