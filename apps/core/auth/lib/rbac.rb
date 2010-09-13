require 'apps/core/auth/models/mixins/rbac'

module RBAC

    def self.define_context(name, permissions)
        @contexts ||= {}
        @contexts[name] = permissions 
    end

    def self.context(name)
        @contexts[name]
    end

end
