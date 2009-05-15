module Spider; module Components
    
    class Menu < Spider::Widget
        tag 'menu'
        
        attr_to_scene :items, :sections, :labels, :links, :current, :current_widget
        attr_reader :current, :current_label
        
        def init
            @items = []
            @sections = {}
            @labels = {}
            @links = {}
            @all_widgets = {}
            @widgets_by_action = {}
        end
        
        def route_widget
            [@current, @_action.split('/', 2)[1]]
        end


        def prepare(action='')
            if (@_action_local)
                act = @_action_local
            else
                redirect(request_path+'/'+@links[@items[0]]) unless @items.empty?
            end
            widget = @widgets_by_action[act]
            raise NotFound.new(request_path) unless widget
            add_widget(widget)
            @current = widget.id
            @current_widget = widget
            @current_label = @labels[widget.id]
            super
        end
        
        def add(section, label, widget)
            @items << widget.id
            @sections[section] ||= []
            @sections[section] << widget.id
            @labels[widget.id] = label
            w_action = label.downcase.gsub(/\s+/, '_')
            @widgets_by_action[w_action] = widget
            @links[widget.id] = w_action
            @all_widgets[widget.id] = widget
        end
        
        def widget_resources
            return @current_widget.resources if @current_widget
            return []
        end
        
    end
    
end; end