require 'apps/core/auth/models/mixins/rbac_provider'

module RBAC

    def self.define_context(name, permissions=nil, options={})
        permissions ||= Spider::OrderedHash[]
        @contexts ||= {}
        permissions.clone.each do |k, v|
            unless v.is_a?(Hash)
               permissions[k] = {:label => v}
            end
        end
        @contexts[name] = permissions
        @options ||= {}
        @options[name] = options
    end

    def self.context(name)
        @contexts[name]
    end
        
    def self.context?(name)
        @contexts[name] != nil
    end
    
    def self.options(name)
        @options[name] || {}
    end

end
