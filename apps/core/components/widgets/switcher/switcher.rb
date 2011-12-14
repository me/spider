module Spider; module Components
    
    class Switcher < Spider::Widget
        tag 'switcher'
        
        attr_to_scene :current
        is_attribute :default
        attr_reader :current, :current_label, :links
        
        default_template 'default'
        
        
        def init
            @sections = {}
            @labels = {}
            @links = {}
            @first_link = nil
            @content_by_label = {}
            @labels_by_action = {}
            @link_mode = :path
            @current_action = nil
            @inline_widgets = {}
            @inline_w_order = []
        end
        
        def route_widget
            return nil unless @current.is_a?(Spider::Widget)
            [@current.id, @_action.split('/', 2)[1]]
        end


        def prepare(action='')
            act = @_action_local || @default
            @current_action = act
            @scene.current_action = @current_action
            if @labels_by_action[act] && content = @content_by_label[@labels_by_action[act]]
                # must add the widget here so that it gets processed in super
                add_widget(content) if content.is_a?(Spider::Widget)
            end
            
            init_widgets
            
            
            # The widget object gets instantiated in super, so it is available now
            @inline_w_order.each do |id|
                iw = @inline_widgets[id]
                add(iw[:label], @widgets[id], iw[:section])
            end
            
            redirect(widget_request_path+'/'+@first_link) if !act && @first_link
            
            label = @labels_by_action[act]
            content = @content_by_label[label]
            raise NotFound.new(request_path) unless content

            # content must not be set in inline, so it is not rendered by sp:run
            @current = @inline_widgets[content.id.to_sym] ? nil : content
            @current_label = label
            
            super
            
            @sections.each do |section, labels|
                labels.each do |label|
                    @widgets[:menu].add(label, self.link(label), section)
                end
            end
            @widgets[:menu].current = @current_label
            
        end
        
        def add(label, content, section=nil)
            @sections[section] ||= []
            @sections[section] << label
            @labels[content] = label
            @content_by_label[label] = content
            w_act = self.class.label_to_link(label)
            @first_link ||= w_act
            @links[label] = w_act
            @labels_by_action[w_act] = label
        end
        
        def widget_assets
            res = @widgets[:menu].assets
            res += @current.assets if @current
            return res
        end

        def link(label)
            @link_mode == :path ? widget_request_path+'/'+@links[label] : "#{widget_request_path}?_wa[#{full_id}]=#{@links[label]}"
        end
        
        def self.label_to_link(label)
            label.downcase.gsub(/\s+/, '_').gsub(/[^a-zA-Z_]/, '')
        end
        
        def self.parse_content(doc)
            ov = ""
            @inline_widgets = []
            doc.root.search('> [@id]').each do |w|
                w_id = w.get_attribute('id')
                w_label = w.get_attribute('switcher:label') || w_id
                w_section = w.get_attribute('switcher:section')
                w.remove_attribute('switcher:label')
                w.remove_attribute('switcher:section')
                ov += %Q{<tpl:pass sp:if="@current_action == '#{w_id}'">#{w.to_s}</tpl:pass>}
                inline_attrs = %Q{id="#{w_id}" label="#{w_label}"}
                inline_attrs += %Q{ section="#{w_section}"} if w_section
                w.swap(%Q{<switcher:inline-widget #{inline_attrs}/>})
            end
            override = Hpricot(%Q{<tpl:append search="#content">#{ov}</tpl:append>}).root
            parse_override(override)
            runtime, soverrides = super(doc)
            return [runtime, [override] + soverrides]
        end
        
        def parse_runtime_content(doc, src_path)
            doc = super
            @inline_widgets = {}
            doc.search('switcher:inline-widget').each do |w|
                w_id = w.get_attribute('id').to_sym
                @inline_widgets[w_id] = {:label => w.get_attribute('label')}
                @inline_w_order << w_id
            end
            doc.search('switcher:inline-widget').remove
            doc
        end
        
        
    end
    
end; end
