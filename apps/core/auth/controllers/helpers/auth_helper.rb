module Spider; module Auth

    module AuthHelper
        include Spider::Helpers::HTTP

        def self.included(mod)
            mod.extend(ClassMethods)
        end

        module ClassMethods

            def require_user(params=nil)
                params ||= {}
                redirect_to = params[:redirect_to] || 'login'
                define_method(:before) do |*args|
                    Spider::Logger.debug("NEW SESSION:")
                    Spider::Logger.debug(@request.session)
                    if (@request.session['uid'])
                        Spider::Auth.current_user = @request.session['uid']
                    end
                    args ||= []
                    action = args.shift
                    good = false
                    unl = params[:unless]
                    if (unl)
                        unl = [unl] unless unl.is_a?(Array)
                        unl.each do |p|
                            if ((p.is_a?(Regexp) && action =~ p) || action == p)
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
                            Spider::Logger.debug("GOOD BECAUSE USER IS #{user.uid}")
                            good = true
                            if (params[:groups])
                                good = false
                                user.groups.each do |group|
                                    good = true if (params[:groups].include?(group.label) || params[:groups.include?(group.gid)])
                                end
                            end
                        end
                        redir_url = params[:login_success] || @request.env['REQUEST_URI']
                        redirect_to += '?redirect='+@request.escape(redir_url)
                        redirect(redirect_to, Spider::Helpers::HTTP::TEMPORARY_REDIRECT) unless good
                    end
                    super
                end
            end


        end

    end

end; end