module Spider; module Auth
    
    class LoginController < Spider::Controller
        include Spider::Helpers::HTTP
        
        def before(action='')
            super
            @response.headers['Content-Type'] = 'text/html'
        end
        
        def index
            @request.session['login_redirect'] = @request.params['redirect'] if (@request.params['redirect'])
            render('login')
        end
        
        def do_login
            user = LoginUser.find(:login => @request.params['login'], :password => @request.params['password'])
            if (user.length == 1)
                @request.session['uid'] = user[0].uid
                Spider::Logger.debug("SESSION:")
                Spider::Logger.debug(@request.session)
                Spider::Auth.current_user = user[0].uid
                if (@request.session['login_redirect'])
                    redir_to = @request.session['login_redirect']
                    @request.session.delete('login_redirect')
                    redirect(redir_to)
                else
                    print "OK! LOGGATO!"
                end
            else
                @scene.failed_login = true
                @scene.login = @request.params['login']
                index
            end
        end
        
    end
    
    
end; end