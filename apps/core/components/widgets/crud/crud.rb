

module Spider; module Components
    
    class Crud < Spider::Widget
        tag 'crud'
        is_attr_accessor :model, :required => true
        is_attribute :action, :type => Symbol, :default => :table
        attribute :table_elements
        i_attr_accessor :table_widget
        i_attr_accessor :form_widget
        is_attribute :allow_create, :type => Spider::Bool, :default => true
        attribute :"new-link"
        attribute :"edit-link"
        attr_accessor :fixed

        def route_widget
            [@action, @_action]
        end

        def table
            @widgets[:table]
        end

        def form
            @widgets[:form]
        end
        
        def prepare(action='')
            @action = (@_action_local && !@_action_local.empty?) ? :form : :table
            @_pass_action = (@action == :form) ? @_action : nil
            @model = const_get_full(@model) if @model.is_a?(String)
            @scene.saved = flash[:saved]
            if params['delete_cancel']
                params.delete('delete')
                params.delete('do_delete')
            end
            if params['delete'] && !params['do_delete'] && params['selected']
                @scene.ask_delete = true
            end
            if @action == :table && @table_widget
                custom_table = create_widget(@table_widget, 'table')
                custom_table.model = @model if custom_table.is_a?(Spider::Components::Table)
                @scene.custom_table = custom_table
            end
            if @action == :form && @form_widget
                custom_form = create_widget(@form_widget, 'form')
                custom_form.model = @model if custom_form.is_a?(Spider::Forms::Form)
                @scene.custom_form = custom_form
            end
            
            super
            transient_session[:table_params] ||= @widgets[:table].params if @widgets[:table]
            
            @scene.new_link = attributes[:"new-link"] || widget_request_path+'/new'
            if @action == :table
                if @widgets[:table].is_a?(Spider::Components::Table) && !@widgets[:table].is_a?(Spider::Components::SearchTable)
                    @scene.show_table_search = true
                end
                if params['do_delete'] && params['selected'] && params['selected'].length > 0
                    delete_rows
                    flash[:deleted] = true
                    return redirect(widget_request_path)
                elsif params['delete'] && params['selected']
                    @scene.ask_delete = true
                    rows = []
                    descs = @model.find({ @model.primary_keys[0].name => params['selected'].keys[0..9]})
                    descs.each { |obj| rows << obj.to_s }
                    total = params['selected'].keys.length
                    rows << "Altri #{total - 10}" if total > 10
                    @widgets[:ask_delete].scene.rows_to_del = rows
                end
            elsif @action == :form
           #     debugger
                if @widgets[:form].saved?
                    flash[:saved] = true
                    if @widgets[:form].saved_and_new?
                        redirect(widget_request_path+'/new')
                    elsif @widgets[:form].saved_and_stay?
                        redirect(widget_request_path+'/'+@widgets[:form].pk)
                    else
                        redirect(widget_request_path)
                    end
                end
            end
            
        end
        
        def prepare_widgets
            if @action == :table && @widgets[:table]
                @key_element = @model.primary_keys[0].name
                table_page = nil
                if transient_session[:table_params]
                    table_page = transient_session[:table_params]['page'] if transient_session[:table_params]['page']
                end
                table_page = 1 if params['table_q'] || params['clear_table_q']
                @widgets[:table].page = table_page if @widgets[:table].respond_to?(:page)
                t_els = @attributes[:table_elements]
                if t_els && @widgets[:table].class.attribute?(:elements)
                    @widgets[:table].attributes[:elements] = t_els
                end
                @widgets[:table].scene.key_element = @key_element
                @widgets[:table].scene.crud_path = @full_path
                @widgets[:table].scene.crud = widget_to_scene(self)
                if @widgets[:table].respond_to?(:add_condition)
                    @table_q = params['table_q']
                    @table_q ||= transient_session[:table_q]
                    @table_q = nil if params['clear_table_q']
                    if @table_q
                        @widgets[:table].add_condition(@model.free_query_condition(@table_q))
                    end
                    transient_session[:table_q] = @table_q
                    if @condition && @widgets[:table]
                        @widgets[:table].add_condition(@condition)
                    end
                    @scene.table_q = @table_q
                end
            end
            if @fixed
                if @widgets[:table] && @widgets[:table].respond_to?(:add_condition)
                    c = Spider::Model::Condition.new(@fixed)
                    @widgets[:table].add_condition(c)
                elsif @widgets[:form]
                    @widgets[:form].fixed = @fixed
                end
            end
            if @widgets[:ask_delete]
                @widgets[:ask_delete].add_action('_w'+param_name(self)+'[delete_cancel]', _("Cancel"))
                @widgets[:ask_delete].add_action('_w'+param_name(self)+'[do_delete]', _('Ok'), "danger")
            end
            
            super
            if @scene._parent.admin_breadcrumb && @widgets[:form]
                @scene._parent.admin_breadcrumb.concat(@widgets[:form].breadcrumb)
            end
            
        end

        
        def after_widget(id)
            if id == :table && @widgets[:table].is_a?(Spider::Components::Table)
                links = {}
                table_rows = @widgets[:table].scene.data
                link_base = attributes[:"edit-link"] || widget_request_path
                table_rows.each_index do |i|
                    links[i] = "#{link_base}/#{Spider::HTTP.urlencode(table_rows[i][@key_element])}"
                end
                @widgets[:table].scene.links_to_form = links
            end
        end
        
        def delete_rows
            params['selected'].keys.each do |key|
                obj = @model.get(@model.primary_keys[0].name => key)
                obj.delete
            end
        end
        
    end
    
end; end