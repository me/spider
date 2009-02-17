module Spider; module Auth

    module AuthHelper

        def self.included(mod)
            mod.extend(ClassMethods)
        end
        
        def before(action='', *arguments)
            debug("REQUIRE_USER BEFORE")
            self.class.auth_require_users.each do |params|
                
                if (@request.session['uid'])
                    Spider::Auth.current_user = @request.session['uid']
                end
                good = false
                unl = params[:unless]
                debug("ACTION IS: #{action}")
                if (unl)
                    unl = [unl] unless unl.is_a?(Array)
                    unl.each do |p|
                        if ((p.is_a?(Regexp) && action =~ p) || action == p)
                            debug("GOOD BECAUSE #{p}")
                            good = true
                        end
                    end
                end
                only = params[:only]
            
                if (only)
                    only = [only] unless only.is_a?(Array)
                    good = true
                    only.each do |p|
                        if ((p.is_a?(Regexp) && action =~ p) || action == p)
                            good = false
                        end
                    end
                end
                if (!good)
                    user = Spider::Auth.current_user
                    if (user)
                        debug("GOOD BECAUSE USER #{user}")
                        good = true
                        if (params[:groups])
                            good = false
                            user.groups.each do |group|
                                good = true if (params[:groups].include?(group.label) || params[:groups.include?(group.gid)])
                            end
                        end
                    end
                    debug("UNAUTHORIZED!") unless good
                    raise Unauthorized unless good
                end
            end
            super
        end

        module ClassMethods

            def require_user(params=nil)
                params ||= {}
                @auth_require_users ||= []
                @auth_require_users << params
            end
            
            def auth_require_users
                @auth_require_users || []
            end


        end

    end

end; end