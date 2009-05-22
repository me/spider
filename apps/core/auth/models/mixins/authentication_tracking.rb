module Spider; module Auth
    
    module AuthenticationTracking
        
        def self.included(mod)
            mod.element :last_login, DateTime, :label => _('Last login'), :read_only => true
            mod.element :login_count, Fixnum, :label => _('Login count'), :read_only => true
        end
        
        def authenticated(method)
            self.login_count ||= 0
            self.login_count += 1
            self.last_login = DateTime.now
            save
        end
        
    end
    
end; end