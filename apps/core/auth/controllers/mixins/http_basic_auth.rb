module Spider; module Auth
    
    module HTTPBasicAuth
        include HTTP
        
        def before(action='', *arguments)
            if (uid = check_basic_auth(LoginAuthenticator.new))
                @request.session['uid'] = uid
                Spider::Auth.current_user = uid
            end
            super
        end
        
        def try_rescue(exc)
            if (exc.is_a?(Unauthorized))
                challenge_basic_auth
            else
                super
            end
        end
        
    end
    
end; end