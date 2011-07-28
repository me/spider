module Spider; module Auth

    module RBACProvider
        
        def self.included(model)
            model.extend(ClassMethods)
        end
        
        # If the second argument is a symbol, it will be interpreted as the context
        def can?(permission, obj=nil, context=nil)
            if obj.is_a?(Symbol)
                context = obj
                obj = nil
            end
            context ||= self.class.rbac_contexts.first
            permission = permission.to_sym
            el = self.class.rbac_provider_elements[context]
            options = RBAC.options(context)
            if options[:superuser]
                val = nil
                val = self.get(options[:superuser]) if self.class.elements[options[:superuser]]
                return true if val
            end
            val = self.get(el)
            has_perm = false
            val.each do |v|
                if v.id.to_sym == permission
                    has_perm = true
                    break
                end
            end
            perm_details = RBAC.context(context)[permission]
            if has_perm
                return true unless perm_details[:with_models] && obj
                model_el = self.class.elements_array.select{ |el| 
                    el.attributes[:rbac] == [context, permission] && el.type == obj.class
                }.first
                return false unless model_el
                return true if self.get(model_el).include?(obj)
                return false
            end
            self.class.rbac_inherit_from.each do |element|
                val = self.get(element)
                val = [val] unless val.is_a?(Enumerable)
                val.each do |v|
                    return true if v.can?(permission, obj, context)
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
                @rbac_provider_elements[context] = :"#{context}_permissions"
                inline_data = Spider::OrderedHash.new
                permissions = RBAC.context(context)
                options = RBAC.options(context)
                inline_data = RBAC.labels(context)
                rbac_name = @rbac_provider_elements[context]
                el_label = options[:element_label] || _("%s permissions") % context.to_s.gsub(/_+/, ' ').capitalize
                
                self.multiple_choice rbac_name, inline_data,
                    :label => el_label,
                    :inline_model => [[:id, String, {:primary_key => true}], [:desc, String]]
                permissions.each do |k, v|
                    if models = v[:with_models]
                        models.each do |model_h|
                            unless model_h.is_a?(Hash)
                                model_h = {:model => model_h}
                            end
                            model = model_h[:model]
                            model_name = model.name
                            parts = model_name.split('::')
                            self_parts = self.name.split('::')
                            el_name = model_h[:element]
                            reverse_name = model_h[:reverse]
                            unless el_name && reverse_name
                                model_name = ""
                                self_name = ""
                                0.upto(parts.length-1) do |i|
                                    next if parts[i] == self_parts[i]
                                    if i < parts.length - 2
                                        model_name = parts[i..-2].join('_')+'_'
                                        self_name = self_parts[i..-2].join('_')+'_'
                                    end
                                    model_name += model.label_plural_
                                    self_name += self.label_plural_
                                    model_name.downcase!
                                    self_name.downcase!
                                    break
                                end
                                el_name ||= "#{context}_#{k}_#{model_name}".to_sym
                                reverse_name ||= "#{context}_#{k}_#{self_name}".to_sym
                            end
                            choice_condition = Spider::Model::Condition.new{ |provider| (provider.__el(rbac_name) == k) }
                            if self.elements[options[:superuser]]
                                choice_condition.and(Spider::Model::Condition.new{ |provider|
                                    (provider.__el(options[:superuser]) .not true)
                                })
                            end
                            attributes = {
                                :add_multiple_reverse => {
                                    :name => reverse_name, :rbac_reverse => [context, k], :version_content => false, :association => :multiple_choice,
                                    :choice_condition => choice_condition
                                }, :delete_cascade => true, :rbac => [context, k], :version_content => false, 
                                   :association => :multiple_choice
                            }
                            labels = v[:model_labels]
                            if labels && labels[model] && lbls = labels[model][self.name]
                                attributes[:label] = lbls[0]
                                attributes[:add_multiple_reverse][:label] = lbls[1]
                            end
                            self.many el_name, model, attributes
                        end
                    end
                end
                self.elements[@rbac_provider_elements[context]].type.translate = true
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
