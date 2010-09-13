module Spider; module Auth

    module RBACProvider
        
        def self.included(model)
            model.extend(ClassMethods)
        end
        
        def can?(permission, context=nil)
            context ||= self.class.rbac_contexts.first
            el = self.class.rbac_provider_elements[context]
            val = self.get(el)
            val.each do |v|
                return true if v.id == permission
            end
            self.class.rbac_inherit_from.each do |element|
                val = self.get(element)
                val = [val] unless val.is_a?(Enumerable)
                val.each do |v|
                    return true if v.can?(permission, context)
                end
            end
            return false
        end
        
        module ClassMethods
            
            def rbac_contexts
                (@rbac_provider_elements || {}).keys
            end
            
            def rbac_provider_for(context)
                @rbac_provider_elements ||= {}
                @rbac_provider_elements[context] = :"#{context}_#{_('permissions')}"
                self.multiple_choice @rbac_provider_elements[context], RBAC.context(context),
                    :label => _("%s permissions") % context.to_s.capitalize
            end
            
            def rbac_provider_elements
                @rbac_provider_elements || {}
            end
            
            def rbac_inherit_from(element=nil)
                @rbac_inherit_from ||= []
                @rbac_inherit_from << element if element
                @rbac_inherit_from
            end
            
        end
        
    end
    
end; end