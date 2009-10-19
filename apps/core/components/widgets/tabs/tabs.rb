require 'apps/core/components/widgets/menu/menu'

module Spider; module Components
    
    class Tabs < Spider::Components::Switcher
        tag 'tabs'
        
        def parse_runtime_content(doc)
            doc = super
            doc.search('tab').each do |tab|
                t = nil
                if (tab.attributes['src'])
                    t = {:src => tab.attributes['src']}
                elsif (tab.attributes['widget'])
                    t = {:widget => tab.attributes[:widget]}
                end
                add
                mods << const_get_full(mod.innerText)
            end
            doc.search('admin:app').each do |app_tag|
                except = []
                if (app_tag.attributes['except'])
                    except = app_tag.attributes['except'].split(',').map{ |e| e.strip }
                end
                app = const_get_full(app_tag.innerText.strip)
                mods += app.models.select{ |m|
                    !m.attributes[:sub_model] && m.mapper.class.write? && !except.include?(m.name.split('::')[-1])
                }.sort{ |a, b| a.name <=> b.name }
            end
            @models ||= []
            @models += mods
            return doc
        end

        
    end
    
end; end