module Spider; module Components
    
    class Switcher < Spider::Widget
        tag 'switcher'
        
        attr_to_scene :current_widget
        attr_reader :current, :current_label
        
        def init
            @items = []
            @sections = {}
            @labels = {}
            @links = {}
            @widgets_by_action = {}
        end
        
        def route_widget
            [@current, @_action.split('/', 2)[1]]
        end


        def prepare(action='')
            if (@_action_local)
                act = @_action_local
            else
                redirect(widget_request_path+'/'+@links[@items[0]]) unless @items.empty?
            end
            widget = @widgets_by_action[act]
            raise NotFound.new(request_path) unless widget
            add_widget(widget)
            @current = widget.id
            @current_widget = widget
            @current_label = @labels[widget.id]
            super
            @sections.each do |section, items|
                items.each do |item|
                    @widgets[:menu].add(section, @labels[item], widget_request_path+'/'+@links[item])
                end
            end
            @widgets[:menu].current = @current_label
            
        end
        
        def add(section, label, widget)
            @items << widget.id
            @sections[section] ||= []
            @sections[section] << widget.id
            @labels[widget.id] = label
            w_action = label.downcase.gsub(/\s+/, '_').gsub(/[^a-zA-Z_]/, '')
            @widgets_by_action[w_action] = widget
            @links[widget.id] = w_action
        end
        
        def widget_resources
            res = @widgets[:menu].resources
            res += @current_widget.resources if @current_widget
            return res
        end
        
    end
    
end; end