require 'lasso'

module Spider; module SAML2

    class LassoBackend < Backend

        def initialize(metadata, private_key, certificate)
            @server = Lasso::Server.new_from_buffers(metadata, private_key, nil, certificate)
            providers = Spider.conf.get('sso.providers')
            providers.each do |label, conf|
                role = conf['role'] == :idp ? Lasso::PROVIDER_ROLE_IDP : Lasso::PROVIDER_ROLE_SP
                @server.add_provider(role, conf['metadata'], conf['pub_key'], conf['cert'])
            end
        end
        
        def parse_authn_request(msg)
            @login = Lasso::Login.new(@server)
            @login.process_authn_request_msg(msg)
            @login.validate_request_msg(true, true)
            return {
                :assertion_consumer_url => @login.request.assertionConsumerServiceURL
            }
        end
        

        def authn_response(user_attributes=[], session_index=nil, reauthenticate_at=nil, not_before=nil, not_after=nil)
            dt_format = "%Y-%m-%dT%H:%M:%S%Z"
            reauthenticate_at = reauthenticate_at.strftime(dt_format) if reauthenticate_at.is_a?(Date) || reauthenticate_at.is_a?(Time)
            not_before = not_before.strftime(dt_format) if not_before.is_a?(Date) || not_before.is_a?(Time)
            not_after = not_after.strftime(dt_format) if not_after.is_a?(Date) || not_after.is_a?(Time)
            now = DateTime.now.strftime(dt_format)
            @login.build_assertion(Lasso::SAML_AUTHENTICATION_METHOD_PASSWORD, now, reauthenticate_at, not_before, not_after)    
            if (user_attributes.empty?)
                # Dummy attribute
                user_attributes.push({:name => 'dummy', :value => 'dummy'})
            end
            attribute_statement = Lasso::Saml2AttributeStatement.new
            attributes = Lasso::NodeList.new
            user_attributes.each do |a|
                attribute = Lasso::Saml2Attribute.new
                attribute.name = a[:name]
                a[:name_format] ||= :unspecifed
                attribute.nameFormat = Spider::SAML2::AttributeFormats[a[:name_format]]
                values = a[:values] || [a[:value]]
                attribute_values = Lasso::NodeList.new
                values.each do |v|
                    val = Lasso::Saml2AttributeValue.new
                    text_node = Lasso::MiscTextNode.new
                    text_node.content = v
                    list = Lasso::NodeList.new
                    list.append(text_node)
                    val.any = list
                    attribute_values.append(val)
                end
                attribute.attributeValue = attribute_values
                attributes.append(attribute)
            end
            attribute_statement.attribute = attributes
            attr_stats = Lasso::NodeList.new
            attr_stats.append(attribute_statement)
            @login.response.assertion.get_item(0).attributeStatement = attr_stats
            @login.response.assertion.get_item(0).authnStatement.get_item(0).sessionIndex = session_index if session_index
            @login.build_authn_response_msg
            return {:body => @login.msgBody, :url => @login.msgUrl}
        end
        
        def parse_logout_request(msg)
            @logout = Lasso::Logout.new(@server)
            begin
                @logout.process_request_msg(msg)
                #@logout.validate_request()
            rescue => exc
                raise unless exc.message =~ /Lasso Warning/
            end
            return {
                :session_index => @logout.request.sessionIndex,
                :remote_provider_id => @logout.remoteProviderId
            }
        end
        
        def logout_response
            @logout.build_response_msg
            return {:body => @logout.msgBody, :url => @logout.msgUrl}
        end

    end

end; end