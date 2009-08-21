module Spider; module Components
    
    class List < Spider::Widget
        tag 'list'
        
        i_attribute :lines, :required => :datasource
        i_attr_accessor :queryset, :required => :datasource
        i_attr_accessor :model, :required => :datasource
        i_attribute :keys
        is_attribute :delete, :default => false, :process => lambda{ |v| return true if v == "true"; return false if v == "false"; v }
        is_attribute :delete_param
        is_attribute :sortable
        is_attribute :tree
        is_attr_accessor :actions


        def prepare
            @sublists = []
            if (!@lines)
                @lines = []
                @keys = []
                unless @queryset
                    @queryset = @tree ? @model.roots : @model.all 
                end
                cnt = 0
                @queryset.each do |row|
                    @keys << keys_string(row)
                    if @tree && row.get(@tree).length > 0
                        @sublists[cnt] = create_sublist("sublist_#{cnt}")
                        @sublists[cnt].queryset = row.get(@tree)
                    end
                    @lines << format_line(row)
                    cnt += 1
                end
            end
            @scene.lines = @lines
            @scene.keys = @keys
            @scene.sublists = @sublists
            @attributes[:delete] = @request.path if @attributes[:delete] == true
            @scene.delete_link = @attributes[:delete]
            @scene.delete_link += "?#{@delete_param}" if (@delete_param)
            super
        end
        
        def create_sublist(name)
            w = create_widget(self.class, name, @request, @response)
            w.attributes[:tree] = @tree
            w.attributes[:actions] = @actions
            return w
        end
        
        def keys_string(obj)
            obj.class.primary_keys.map{ |pk| obj.get(pk) }.join(',')
        end
        
        def format_line(obj)
            obj.to_s
        end
        

    end
    
end; end