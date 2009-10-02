module Spider; module Components

    class List < Spider::Widget
        tag 'list'

        i_attribute :lines, :required => :datasource
        i_attr_accessor :queryset, :required => :datasource
        i_attr_accessor :model, :required => :datasource
        i_attribute :keys
        is_attribute :delete, :default => false, :process => lambda{ |v| return true if v == "true"; return false if v == "false"; v }
        is_attribute :delete_param
        is_attribute :sortable; is_attribute :collapsable; is_attribute :collapsed
        is_attribute :tree
        is_attr_accessor :actions
        is_attribute :sub_elements
        is_attribute :is_child
        is_attribute :paginate, :type => Fixnum, :default => false

        def widget_init(action='')
            super
            @sortable = @sortable.to_sym if @sortable
            @tree = @tree.to_sym if @tree
            if (@model && !@queryset)
                @queryset = @tree ? @model.roots : @model.all 
            elsif @queryset
                @model = @queryset.model
            end
        end


        def prepare
            @sublists = []
            if (@sub_elements && @sub_elements.is_a?(String))
                @sub_elements = @sub_elements.split(/,\s+/).map{ |el| el.to_sym }
            end
            @sub_elements ||= []
            @requested_sublists ||= []
            if (@attributes[:paginate])
                @page = params['page'] if params['page']
                @page ||= 1
                @page = @page.to_i
                @offset = ((@page - 1) * @attributes[:paginate])
            end
            if (!@lines)
                @lines = []
                @keys = []
                cnt = 0
                if (@attributes[:paginate])
                    @queryset.offset = @offset
                    @queryset.limit = @attributes[:paginate]
                end
                @queryset.each do |row|
                    @keys << keys_string(row)
                    cnt2 = 0
                    if @tree && row.get(@tree).length > 0
                        sl = create_sublist("sublist_#{cnt}_#{cnt2+=1}")
                        sl.queryset = row.get(@tree)
                        @sublists[cnt] ||= []
                        @sublists[cnt] << sl
                    end
                    @sub_elements.each do |el|
                        sub = row.get(el)
                        sl = create_sublist("sublist_#{cnt}_#{cnt2+=1}")
                        sl.queryset = sub
                        @sublists[cnt] ||= []
                        @sublists[cnt] << sl
                    end
                    @requested_sublists.each do |sl|
                        if (sl['element'])
                            el = @model.elements[sl['element'].to_sym]
                            next unless el # may be ok if the query is polymorphic
                            if (sl['tree'] && el.attributes[:reverse])
                                sub = el.model.send("#{sl['tree']}_roots")
                                sub.condition[el.attributes[:reverse]] = row
                            else
                                sub = row.get(sl['element'].to_sym)
                            end
                        end
                        sl.delete('element')
                        sl = create_sublist("sublist_#{cnt}_#{cnt2+=1}", sl)
                        sl.queryset = sub
                        @sublists[cnt] ||= []
                        @sublists[cnt] << sl
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
            @css_classes << 'sortable' if @sortable
            @css_classes << 'collapsable' if @collapsable
            @css_classes << 'collapsed' if @collapsed
            @css_classes << 'sublist' if @attributes[:is_child]
            @css_classes << 'tree' if @attributes[:tree]
            super
        end

        def create_sublist(name, attributes = {})
            w = create_widget(self.class, name, @request, @response)
            w.attributes[:tree] = @tree
            w.attributes[:actions] = @actions
            w.attributes[:is_child] = true
            attributes.each do |key, val|
                w.attributes[key.to_sym] = val
            end
            return w
        end

        def keys_string(obj)
            obj.class.primary_keys.map{ |pk| obj.get(pk) }.join(',')
        end

        def format_line(obj)
            obj.to_s
        end

        def parse_runtime_content(doc, src_path='')
            doc.search('sublist').each do |sl|
                @requested_sublists ||= []
                @requested_sublists << sl.attributes
            end
        end

        __.json
        def sort(id, pos)
            raise "List #{@id} is not sortable" unless @sortable
            obj = @model.new(id)
            obj.set(@sortable, pos)
            obj.save
            $out << "{res: 'ok'}"
        end
        
        __.json
        def tree_sort(id, parent_id, prev_id=nil)
            #debugger
            raise "List #{@id} is not a tree" unless @tree
            raise "List #{@id} is not sortable" unless @sortable
            obj = @model.new(id)
            parent = @model.new(parent_id) if parent_id && !parent_id.empty?
            prev = @model.new(prev_id) if prev_id && !prev_id.empty?
            raise "No parent or prev given" unless parent || prev
            tree_el = @model.elements[@tree]
            obj_parent = obj.get(tree_el.attributes[:reverse])
#            if (obj_parent)
             @model.mapper.tree_remove(tree_el, obj)
#            end
            if (prev)
                @model.mapper.tree_insert_node_right(tree_el, obj, prev)
            else
                @model.mapper.tree_insert_node_first(tree_el, obj, parent)
            end
            obj.save
            $out << "{res: 'ok'}"
        end


    end

end; end