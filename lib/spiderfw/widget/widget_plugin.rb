module Spider
    
    module WidgetPlugin
        
        def self.included(mod)
            mod.extend(ModuleMethods)
            mod.module_eval{ include Annotations }
        end
        
        module ModuleMethods
            
            def self.plugin_name
                @plugin_name
            end
            
            def plugin_for(widget, plugin_name)
                @plugin_name = plugin_name
                widget.add_plugin(plugin_name, self)
                @path = File.dirname(File.expand_path(caller[0].split(':')[0]))
            end
            
            def get_overrides
                overrides = []
                path = @path+'/'+Inflector.underscore(self.to_s.split('::')[-1])+'.shtml'
                doc = open(path){ |f| Hpricot.XML(f) }
                doc.root.each_child do |child|
                    next unless child.is_a?(Hpricot::Elem)
                    overrides << child
                end
                return overrides
            end
            
        end
        
    end
    
end