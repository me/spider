module Spider
    
    module ControllerMixin
        
        def self.included(mod)
            extend_recipient(mod)
        end
        
        def self.extend_recipient(mod)
            mod.extend(ControllerMixinModuleMethods)
            mod.extend(ControllerMixinClassMethods) if mod.is_a?(Class)
            mod.controller_mixins << self
            mod.extend(self.const_get(:ClassMethods)) if self.const_defined?(:ClassMethods)
        end
        
        module ControllerMixinModuleMethods
            
            def controller_mixins
                @controller_mixins ||= []
            end
            
            def included(mod)
                extend_recipient(mod)
                super
            end
            
            def extend_recipient(mod)
                mod.extend(ControllerMixinModuleMethods)
                mod.extend(ControllerMixinClassMethods) if mod.is_a?(Class)
                mod.controller_mixins << self
                mod.extend(self.const_get(:ClassMethods)) if self.const_defined?(:ClassMethods)
            end
            
        end
        
        module ControllerMixinClassMethods
            
            def inherited(klass)
                self.controller_mixins.each do |mod|
                    klass.send(:include, mod)
                end
                super
            end
            
        end
                
    end
    
end