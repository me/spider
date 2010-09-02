

module Spider; module Components
    
    class Crud < Spider::Widget
        tag 'crud'
        is_attr_accessor :model, :required => true
        is_attribute :action, :type => Symbol, :default => :table
        attribute :table_elements
        attr_accessor :fixed

        def route_widget
            [@action, @_action]
        end
        
        def prepare(action='')
            @action = (@_action_local && !@_action_local.empty?) ? :form : :table
            @_pass_action = (@action == :form) ? @_action : nil
            @scene.saved = flash[:saved]
            if (params['delete_cancel'])
                params.delete('delete')
                params.delete('do_delete')
            end
            if (params['delete'] && !params['do_delete'] && params['selected'])
                @scene.ask_delete = true
            end
            super
            transient_session[:table_params] ||= @widgets[:table].params if (@widgets[:table])
            
            if (@action == :table)
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
            elsif (@action == :form)
           #     debugger
                if (@widgets[:form].saved?)
                    flash[:saved] = true
                    if (@widgets[:form].saved_and_new?)
                        redirect(widget_request_path+'/new')
                    elsif (@widgets[:form].saved_and_stay?)
                        redirect(widget_request_path+'/'+@widgets[:form].pk)
                    else
                        redirect(widget_request_path)
                    end
                end
            end
            
        end
        
        def prepare_widgets
            if (@action == :table && @widgets[:table])
                @key_element = @model.primary_keys[0].name
                table_page = nil
                if (transient_session[:table_params])
                    table_page = transient_session[:table_params]['page'] if transient_session[:table_params]['page']
                end
                table_page = 1 if params['table_q'] || params['clear_table_q']
                @widgets[:table].page = table_page
                @widgets[:table].attributes[:elements] = @attributes[:table_elements]
                @widgets[:table].scene.key_element = @key_element
                @widgets[:table].scene.crud_path = @full_path
                @widgets[:table].scene.crud = widget_to_scene(self)
                @table_q = params['table_q']
                @table_q ||= transient_session[:table_q]
                @table_q = nil if params['clear_table_q']
                if (@table_q)
                    @widgets[:table].add_condition(@model.free_query_condition(@table_q))
                end
                transient_session[:table_q] = @table_q
                if(@condition && @widgets[:table])
                    @widgets[:table].add_condition(@condition)
                end
                @scene.table_q = @table_q
            end
            if (@fixed)
                if (@widgets[:table])
                    c = Spider::Model::Condition.new(@fixed)
                    @widgets[:table].add_condition(c)
                elsif (@widgets[:form])
                    @widgets[:form].fixed = @fixed
                end
            end
            if (@widgets[:ask_delete])
                @widgets[:ask_delete].add_action('_w'+param_name(self)+'[delete_cancel]', _("Cancel"))
                @widgets[:ask_delete].add_action('_w'+param_name(self)+'[do_delete]', _('Ok'))
            end
            
            super
            
        end
        
        def after_widget(id)
            if (id == :table)
                links = {}
                table_rows = @widgets[:table].scene.data
                table_rows.each_index do |i|
                    links[i] = "#{widget_request_path}/#{Spider::HTTP.urlencode(table_rows[i][@key_element])}"
                end
                @widgets[:table].scene.links_to_form = links
            end
        end
        
        def delete_rows
            @model.mapper.delete({ @model.primary_keys[0].name => params['selected'].keys})
        end
        
    end
    
end; end