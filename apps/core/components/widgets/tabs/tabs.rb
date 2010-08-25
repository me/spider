require 'apps/core/components/widgets/menu/menu'

module Spider; module Components
    
    class Tabs < Spider::Widget
        tag 'tabs'
        
        def init
            @tabs = []
            @tabs_labels = {}
        end
        
        def add_tab(id, label)
            @tabs << id
            @tabs_labels[id] = label
        end
        
        def prepare
            super
            @active_tab ||= @tabs.first
            @scene << {
                :active_tab => @active_tab,
                :tabs => @tabs,
                :tabs_labels => @tabs_labels
            }
        end
        
        def self.parse_content(doc)
            content, overrides = super
            doc = Hpricot(content)
            tabs = []
            tabs_override = '<tpl:override search="#tabs_content">'
            doc.search('tab').each do |tab|
                tab_id = tab.get_attribute('id')
                tabs_override += '<div sp:if="@active_tab == \''+tab_id+'\'>'
                tabs_override += '<sp:parent-context>'
                tabs_override += tab.innerHTML
                tabs_override += '</sp:parent-context>'
                tabs_override += '</div>'
                tab.innerHTML = ''
            end
            tabs_override += '</tpl:override>'
            overrides << Hpricot(tabs_override).root
            return doc.to_s, overrides
        end
        
        def parse_runtime_content(doc, src_path='')
            doc = super
            return doc if !doc.children || doc.children.empty?
            doc.search('tab').each do |tab|
                tab_id = tab.get_attribute('id')
                label = tab.get_attribute('label')
                add_tab(tab_id, label)
            end
            return doc
        end
        
        
        # def self.compile_block(el, id, attributes, options)
        #     init_params = Spider::TemplateBlocks::Widget.attributes_to_init_params(attributes)
        #     init = "w = add_widget('#{id}', #{self}.new(@request, @response), {#{init_params.join(', ')}}, '', nil)\n"
        #     c = "yield :#{id}\n"
        #     tabs_content = []
        #     el.search('tab').each do |tab|
        #         tab_id = tab.get_attribute('id')
        #         label = tab.get_attribute('label')
        #         init += "w.add_tab('#{tab_id}', '#{label}')\n"
        #         raise TemplateCompileError, "Tabs widget #{id} has a tab without a label attribute" unless label
        #         tab_c, tab_init = Spider::TemplateBlocks.compile_content(tab, c, init, options)
        #         init += "if scene[:active_tab] == '#{tab_id}'\n"
        #         init += tab_init
        #         init += "end\n"
        #         c += "debugger\n"
        #         c += "if self[:active_tab] == '#{tab_id}'\n"
        #         c += tab_c
        #         c += "end\n"
        #         
        #     end
        #     return [init, c]
        # end

        
    end
    
end; end