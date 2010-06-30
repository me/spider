module Spider
    
    module WidgetPlugin
        
        def self.included(mod)
            mod.extend(ModuleMethods)
            mod.module_eval{ include Annotations }
        end
        
        module ModuleMethods
            
            def plugin_name
                @plugin_name
            end
            
            def plugin_for(widget, plugin_name)
                @plugin_name = plugin_name
                widget.add_plugin(plugin_name, self)
                @path = File.dirname(File.expand_path(caller[0].split(':')[0]))
            end
            
            def overrides_path
                @path+'/'+Inflector.underscore(self.to_s.split('::')[-1])+'.shtml'
            end
            
            def get_overrides
                overrides = []
                path = overrides_path
                doc = open(path){ |f| Hpricot.XML(f) }
                doc.root.each_child do |child|
                    next unless child.is_a?(Hpricot::Elem)
                    overrides << child
                end
                return overrides
            end
            
            def get_assets
                path = overrides_path
                return open(path){ |f| Hpricot.XML(f) }.root.children_of_type('tpl:asset').map{ |el|
                    Spider::Template.parse_asset_element(el)
                }
            end
            
        end
        
    end
    
end