module Spider; module Components
    
    class Menu < Spider::Widget
        tag 'menu'
        
        attr_to_scene :items, :labels, :links, :current, :current_widget
        attr_reader :current, :current_label
        
        def init
            @items = []
            @labels = {}
            @links = {}
            @all_widgets = {}
        end

        def start
            @action = params['action']
            @action ||= session[:current]
            if (@action)
                @current = @action
            else
                @current = @items[0]
            end
            session[:current] = @current
            add_widget(@all_widgets[@current])
            @current_widget = @widgets[@current.to_sym]
            @current_label = @labels[@current]
        end
        
        def add(label, widget)
            @items << widget.id
            @labels[widget.id] = label
            @links[widget.id] = @request.path+'?_w'+params_for(self, {:action => widget.id})
            @all_widgets[widget.id] = widget
        end
        
        def widget_resources
            return @current_widget.resources if @current_widget
            return []
        end
        
    end
    
end; end