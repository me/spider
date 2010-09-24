module Spider; module Master

    class LoginController < Spider::Auth::LoginController
    
        layout 'login'
    
        def before(action='', *params)
            @scene.login_title = "Spider Master"
            super
        end
    
        def self.users
            [Master::Admin, Spider::Auth::SuperUser]
        end
    
        def self.default_redirect
            Master.url
        end
    
    end

end; end