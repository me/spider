module Spider; module Components

    class List < Spider::Widget
        tag 'list'

        i_attribute :lines, :required => :datasource
        i_attr_accessor :queryset, :required => :datasource
        i_attr_accessor :model, :required => :datasource
        i_attribute :keys
        is_attribute :delete, :default => false, :process => lambda{ |v| return true if v == "true"; return false if v == "false"; v }
        is_attribute :delete_param
        is_attribute :delete_mode, :default => 'all'
        is_attribute :sortable; is_attribute :collapsable; is_attribute :collapsed
        is_attribute :tree
        is_attr_accessor :actions
        is_attribute :sub_elements
        is_attribute :is_child
        is_attribute :paginate, :type => Fixnum, :default => false
        is_attribute :searchable, :type => Spider::DataTypes::Bool
        # Display message if list is empty
        attribute :show_empty, :type => Spider::DataTypes::Bool
        # Display empty <ul></ul> (default: false)
        is_attribute :show_empty_list, :type => Spider::DataTypes::Bool
        i_attribute :dereference_junction
        i_attribute :dereference_sort, :type => Spider::DataTypes::Bool, :default => false
        i_attribute :dereference_delete, :type => Spider::DataTypes::Bool, :default => true
        is_attribute :list_tag, :default => 'ul'
        i_attribute :element
        i_attribute :parent_obj

        def widget_init(action='')
            super
            @sortable = @sortable.to_sym if @sortable
            @tree = @tree.to_sym if @tree
            @model = const_get_full(@model) if @model.is_a?(String)
            if (@model && !@queryset)
                @queryset = @tree ? @model.roots : @model.all 
            elsif @queryset
                @model = @queryset.model
            end
        end


        def prepare
            @scene.start_list_tag = "<#{@list_tag}>"
            @scene.close_list_tag = "</#{@list_tag}>"
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
                @scene.page = @page
            end
            @keys = []
            @delete_keys = []
            @values = []
            if (params['delete'])
                delete(params['delete'])
            end
            @dereference_junction = @dereference_junction.to_sym if @dereference_junction
            css_model = @dereference_junction ? @model.elements[@dereference_junction].model : @model
            @scene.model_class = css_model_class(css_model)
            
            @css_classes << 'sortable' if @sortable
            @css_classes << 'collapsable' if @collapsable
            @css_classes << 'collapsed' if @collapsed
            @css_classes << 'sublist' if @attributes[:is_child]
            @css_classes << 'tree' if @attributes[:tree]
            @scene.show_empty = @attributes[:show_empty]
            if (!@lines && @queryset)
                if (@attributes[:paginate])
                    @queryset.offset = @offset
                    @queryset.limit = @attributes[:paginate]
                end
                @scene.search_submit_text = _("Go")
                @scene.search_clear_text = _("Clear")
                @search_query = params['q'] || session['q']
                @search_query = nil if params['clear']
                session['q'] = @search_query
                if (@attributes[:searchable] && @search_query)
                    @scene.search_query = @search_query.to_s
                    @queryset.condition.and(@queryset.model.free_query_condition(@search_query))
                end
            end
            if (@widget_target)
                first, rest = @widget_target.split('/', 2)
                if first =~ /sublist_(\d+)_(.+)/
                    cnt = $1.to_i
                    sublist_id = $2
                    found = @requested_sublists.select{ |sbl| sbl['id'] == sublist_id }[0]
                    row = @queryset[cnt]
                    if (@dereference_junction)
                        row = row.get(@dereference_junction)
                    end
                    create_requested_sublist(found, row, cnt) if (found)
                end
            end
            super
        end
        
        def run
            if (!@lines && @queryset)
                @lines = []
                cnt = 0
                @queryset.each do |row|
                    if (@dereference_junction)
                        dr_keys = keys_string(row)
                        row = row.get(@dereference_junction)
                    end
                    @keys << keys_string(row)
                    if (@dereference_junction && !@dereference_sort)
                        @sort_keys ||= []
                        @sort_keys << dr_keys
                    end
                    @delete_keys << ((@dereference_junction && !@dereference_delete) ? dr_keys : @keys.last)
                    cnt2 = 0
                    if @tree && row.get(@tree).length > 0
                        sl = create_sublist("sublist_#{cnt}_#{cnt2+=1}")
                        if (@dereference_junction && @model.elements[@tree].model == @model.elements[@dereference_junction].model)
                            sl.attributes[:dereference_junction] = nil
                        end
                        sl.queryset = row.get(@tree)
                        @sublists[cnt] ||= []
                        @sublists[cnt] << sl
                        sl.run
                    end
                    @sub_elements.each do |el|
                        sub = row.get(el)
                        sl = create_sublist("sublist_#{cnt}_#{el}")
                        sl.queryset = sub
                        @sublists[cnt] ||= []
                        @sublists[cnt] << sl
                        sl.run
                    end
                    @requested_sublists.each do |sbl|
                        sl = create_requested_sublist(sbl, row, cnt)
                        sl.run
                    end
                    @values << row
                    @lines << format_line(row)
                    cnt += 1
                end
                if (@attributes[:paginate])
                    @scene.has_more = @queryset.has_more?
                    @scene.pages = (@queryset.total_rows.to_f / @attributes[:paginate]).ceil
                end
            end
            @lines ||= []
            @scene.lines = @lines
            @scene.keys = @keys
            @scene.values = @values
            @scene.sublists = @sublists
            @scene.delete_keys = @delete_keys
            @scene.sort_keys = @sort_keys
            @attributes[:delete] = @request.path if @attributes[:delete] == true
            if (@attributes[:delete])
                @scene.delete_link = @attributes[:delete]
                if (@delete_param)
                    @scene.delete_link += "?#{@delete_param}"
                else
                    @scene.delete_link += "?_w#{param_name(self)}[delete]="
                end
            end
        end
        
        def create_requested_sublist(sbl, row, cnt)
            attributes = sbl.attributes.to_hash.clone
            if (attributes['element'])
                el = @model.elements[attributes['element'].to_sym]
                #next unless el # may be ok if the query is polymorphic
                # if (sl['tree'] && el && el.attributes[:reverse])
                #     sub = el.model.send("#{sl['tree']}_roots")
                #     sub.condition[el.attributes[:reverse]] = row
                # else
                sub = row.get(attributes['element'].to_sym)
#                end
            end
            el_name = attributes['element']
            attributes.delete('element')
            sl = create_sublist("sublist_#{cnt}_#{attributes['id']}", attributes)
            if (el && el.model != @model)
                sl.attributes[:model] = el.model
                sl.attributes[:dereference_junction] = nil unless attributes['dereference_junction']
            end
            if (el)
                sl.attributes[:element] = el
                sl.attributes[:parent_obj] = row
            end
            sl.parse_runtime_content_xml("<sp:widget-content>#{sbl.innerHTML}</sp:widget-content>")
            sl.queryset = sub
            sl.css_classes << "sublist_#{el_name}"
            @sublists[cnt] ||= []
            @sublists[cnt] << sl
            return sl
        end

        def create_sublist(name, attributes = {})
            w = create_widget(self.class, name)
            if (attributes['inherit_template'] && @template)
                w.template = @template
            end
            w.attributes[:tree] = @tree
            w.attributes[:actions] = @actions
            w.attributes[:is_child] = true
            @attributes.each do |key, val|
                w.attributes[key.to_sym] = val
            end
            attributes.each do |key, val|
                w.attributes[key.to_sym] = val if w.class.attribute?(key)
            end
            w.widget_before
            return w
        end

        def keys_string(obj)
            obj.keys_string
        end

        def format_line(obj)
            obj.to_s
        end

        def parse_runtime_content(doc, src_path='')
            doc = super
            return doc if !doc.children || doc.children.empty?
            doc.root.children_of_type('sublist').each do |sl|
                raise ArgumentError, "Sublist of #{@id} does not have an id" unless sl['id']
                @requested_sublists ||= []
                @requested_sublists << sl
            end
            return doc.root
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
            unless parent || prev
                if (@parent_obj.class == @model)
                    parent = @parent_obj
                else
                    raise "No parent or prev given" 
                end
            end
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
        
        def delete(id)
            if (@delete_mode == 'all')
                obj = @model.new(id)
                if (@tree)
                    obj.mapper.tree_delete(@model.elements[@tree], obj)
                else
                    obj.delete
                end
            else
                
            end
        end


    end

end; end