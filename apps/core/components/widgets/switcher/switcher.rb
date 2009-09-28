module Spider; module Components
    
    class Switcher < Spider::Widget
        tag 'switcher'
        
        attr_to_scene :current
        is_attribute :default
        attr_reader :current, :current_label
        
        def init
            @items = []
            @sections = {}
            @labels = {}
            @links = {}
            @content_by_action = {}
            @link_mode = :path
        end
        
        def route_widget
            return nil unless @current.is_a?(Spider::Widget)
            [@current.id, @_action.split('/', 2)[1]]
        end


        def prepare(action='')
            if (@_action_local)
                act = @_action_local
            elsif @default
                act = @default
            else
                redirect(widget_request_path+'/'+@links[@items[0]]) unless @items.empty?
            end
            content = @content_by_action[act]
            raise NotFound.new(request_path) unless content
            add_widget(content) if content.is_a?(Spider::Widget)
            @current = content
            @current_label = @labels[content]
            super
            @sections.each do |section, items|
                items.each do |item|
                    menu_link = @link_mode == :path ? widget_request_path+'/'+@links[item] : "#{widget_request_path}?_wa[#{full_id}]=#{@links[item]}"
                    @widgets[:menu].add(@labels[item], menu_link, section)
                end
            end
            @widgets[:menu].current = @current_label
            
        end
        
        def add(label, content, section=nil)
            @items << content
            @sections[section] ||= []
            @sections[section] << content
            @labels[content] = label
            w_action = label.downcase.gsub(/\s+/, '_').gsub(/[^a-zA-Z_]/, '')
            @content_by_action[w_action] = content
            @links[content] = w_action
        end
        
        def widget_assets
            res = @widgets[:menu].assets
            res += @current_widget.assets if @current_widget
            return res
        end
        
        
    end
    
end; end
