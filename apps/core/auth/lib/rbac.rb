require 'apps/core/auth/models/mixins/rbac'

module RBAC

    def self.define_context(name, permissions, options={})
        @contexts ||= {}
        @contexts[name] = permissions 
        @options ||= {}
        @options[name] = options
    end

    def self.context(name)
        @contexts[name]
    end
    
    def self.options(name)
        @options[name] || {}
    end

end
