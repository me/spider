

module Spider; module Components
    
    class Crud < Spider::Widget
        tag 'crud'
        is_attr_accessor :model, :required => true
        is_attribute :action, :type => Symbol, :default => :table
        attribute :table_elements
        
        def prepare
            # debug("CRUD PARAMS:")
            # debug(@request.params)
            # debug(params)
            debug("SESSION:")
            debug(@request.session)
            if params['edit'] || (params['form'] && params['form']['submit'])
                @action = :form
            elsif params['action']
                @action = params['action'].to_sym
            elsif session['action']
                @action ||= session['action'].to_sym
            end
            @scene.saved = flash[:saved]
            if (params['delete_cancel'])
                params.delete('delete')
                params.delete('do_delete')
            end
            if (params['delete'] && !params['do_delete'] && params['selected'])
                @scene.ask_delete = true
            end

        end
        
        def start
            if (@action == :table && @widgets[:table])
                @key_element = @model.primary_keys[0].name
                @widgets[:table].attributes[:elements] = @attributes[:table_elements]
                @widgets[:table].scene.key_element = @key_element
                @widgets[:table].scene.crud_path = @full_path
                @widgets[:table].scene.crud = widget_to_scene(self)
            elsif (@action == :form)
                @widgets[:form].pk = params['edit'] if params['edit']
            end
            if (@widgets[:ask_delete])
                @widgets[:ask_delete].add_action('_w'+param_name(self)+'[delete_cancel]', 'Annulla')
                @widgets[:ask_delete].add_action('_w'+param_name(self)+'[do_delete]', 'Ok')
            end
        end
        
        def after_execute
            if (@action == :table)
                if params['do_delete'] && params['selected'] && params['selected'].length > 0
                    delete_rows
                    flash[:deleted] = true
                    return redirect(@request.path)
                elsif params['delete'] && params['selected']
                    @scene.ask_delete = true
                    rows = []
                    descs = @model.find({ @model.primary_keys[0].name => params['selected'].keys[0..9]})
                    descs.each { |obj| rows << obj.to_s }
                    total = params['selected'].keys.length
                    rows << "Altri #{total - 10}" if total > 10
                    @widgets[:ask_delete].scene.rows_to_del = rows
                end
                if (@widgets[:table])
                    links = {}
                    table_rows = @widgets[:table].scene.rows
                    table_rows.each_index do |i|
                        links[i] = "#{@request_path}?_w"+params_for(self, :edit => table_rows[i][@key_element])
                    end
                    @widgets[:table].scene.links_to_form = links
                end
            elsif (@action == :form)
                # tab_els = @model.elements_array.select{ |el| el.multiple? && el.association != :multiple_choice }
                #                 if (tab_els.length > 0)
                #                     @scene.have_form_tables = true
                #                     tabs = Tabs.new(@request, @response)
                #                     tab_els.each do |el|
                #                         formTable = Table.new(@request, @response)
                #                         formTable.queryset = @widgets[:form].obj[el.name]
                #                         tabs.add(el.label, formTable)
                #                     end
                #                     @widgets[:form_tables] = tabs
                #                 end
                if (@widgets[:form].saved?)
                    flash[:saved] = true
                    redirect("#{@request.path}?_w"+params_for(self, :action => :table))
                end
            end
        end
        
        def delete_rows
            @model.mapper.delete({ @model.primary_keys[0].name => params['selected'].keys})
        end
        
    end
    
end; end