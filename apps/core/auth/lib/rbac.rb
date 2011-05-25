require 'apps/core/auth/models/mixins/rbac_provider'

module RBAC

    def self.define_context(name, permissions=nil, options={})
        permissions ||= Spider::OrderedHash[]
        @contexts ||= {}
        @labels ||= {}
        inline_data = Spider::OrderedHash[]
        permissions.clone.each do |k, v|
            unless v.is_a?(Hash)
               permissions[k] = {:label => v}
            end
            inline_data[k] = permissions[k][:label]
        end
        @contexts[name] = permissions
        @options ||= {}
        @options[name] = options
        @labels[name] = inline_data
    end


    def self.add_to_context(name, key, val)
        val = {:label => val} unless val.is_a?(Hash)
        @contexts[name][key] = val
        @labels[name][key] = val[:label]
    end

    def self.context(name)
        @contexts[name]
    end
        
    def self.context?(name)
        @contexts[name] != nil
    end

    def self.labels(name)
        @labels[name]
    end
    
    def self.options(name)
        @options[name] || {}
    end

end
