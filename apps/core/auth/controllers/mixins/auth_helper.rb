module Spider; module Auth

    module AuthHelper

        def self.included(mod)
            mod.extend(ClassMethods)
            if mod.respond_to?(:define_annotation)
                mod.define_annotation(:require_user) { |k, m, params| k.require_user(params, :only => m) }
            end
        end
        
        def before(action='', *arguments)
            @request.extend(RequestMethods)
            super
            return if action.index(Spider::Auth.route_url) == 0
            return if respond_to?(:serving_static?) && serving_static?(action)
            self.class.auth_require_users.each do |req|
                klasses, params = req
                klasses = [klasses] unless klasses.is_a?(Array)
                @current_require = params
                unl = params[:unless]
                action_match = true
                if (unl)
                    unl = [unl] unless unl.is_a?(Array)
                    unl.each do |p|
                        action_match = !check_action(action, p)
                        break unless action_match
                    end
                end
                only = params[:only]
                if (only)
                    only = [only] unless only.is_a?(Array)
                    action_match = false
                    only.each do |p|
                        action_match = check_action(action, p)
                        break if action_match
                    end
                end
                next unless action_match
                user = nil
                unauthorized_exception = nil
                requested_class = nil
                klasses.each do |klass|
                    requested_class = klass
                    user = klass.restore(@request)
                    if user
                        @request.security[:users] << user
                        if params[:authentication]
                            user = nil unless user.authenticated?(params[:authentication])
                        elsif (params[:check])
                            begin
                                c = params[:check].call(user)
                                user = nil unless c == true
                                raise Unauthorized.new(c, requested_class) if c.is_a?(String)
                                break
                            rescue => exc
                                user = nil
                                unauthorized_exception = exc
                            end
                        else
                            break
                        end
                    end
                end
                unless user
                    msg = Spider::GetText.in_domain('spider_auth'){ _("Please login first") }
                    kl = unauthorized_exception ? unauthorized_exception : Unauthorized
                    raise kl.new(msg, requested_class)
                end
                @request.user = user
            end
            
        end
        
        def try_rescue(exc)
            if (exc.is_a?(Unauthorized))
                base = @current_require[:redirect] ? @current_require[:redirect] : Spider::Auth.request_url+'/login/'
                base = url+'/'+base unless base[0].chr == '/'
                base += '?'
                redir_url = base + 'redirect='+URI.escape(@request.path)
                @request.session.flash[:unauthorized_exception] = {:class => exc.class.name, :message => exc.message}
                redirect(redir_url, Spider::HTTP::TEMPORARY_REDIRECT)
            else
                super
            end
        end
        
        module RequestMethods
            def security
                @security ||= {:users => []}
            end
            def user
                @user
            end
            def user=(val)
                @user = val
            end
            
            def auth(user_class)
                return user_class.restore_from_session(self.session)
            end
            
        end

        module ClassMethods

            def require_user(*args)
                klass = args.shift if (args[0] && !args[0].is_a?(Hash))
                params = args[0]
                params ||= {}
                @auth_require_users ||= []
                @auth_require_users << [klass, params]
            end
            
            def auth_require_users
                @auth_require_users || []
            end


        end

    end

end; end
