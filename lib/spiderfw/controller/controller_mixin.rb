module Spider
    
    module ControllerMixin
        
        def self.included(mod)
           mod.extend(ModuleMethods)
           def mod.included(klass)
                if (@chain_items)
                    @chain_items.each do |method, item|
                        klass.add_chain_item(method, item[0], item[1])
                    end
                end
            end

        end
        
        module ModuleMethods
            
            def before(params={}, &proc)
                add_chain_item(:before, proc, params)
            end
            
            def execute(params={}, &proc)
                add_chain_item(:execute, proc, params)
            end
            
            def after(params={}, &proc)
                add_chain_item(:after, proc, params)
            end
            
            def add_chain_item(method, proc, params)
                @chain_items ||= {}
                @chain_items[method] = [proc, params]
            end
            
            
        end
        
    end
    
end