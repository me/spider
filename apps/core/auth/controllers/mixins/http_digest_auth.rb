require 'apps/core/auth/lib/digest_authenticator'

module Spider; module Auth
    
    module HTTPDigestAuth
        include HTTP
        
        def before(action='', *arguments)
            if (uid = check_digest_auth(Spider::Auth::DigestUser))
                @request.session['uid'] = uid
                Spider::Auth.current_user = uid
            end
            super
        end
        
        def try_rescue(exc)
            if (exc.is_a?(Unauthorized))
                challenge_digest_auth
            else
                super
            end
        end
        
    end
    
end; end