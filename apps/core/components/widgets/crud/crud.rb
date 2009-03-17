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
        end
        
        def start
            if (@action == :table)
                @key_element = @model.primary_keys[0].name
                @widgets[:table].attributes[:elements] = @attributes[:table_elements]
                @widgets[:table].scene.key_element = @key_element
                @widgets[:table].scene.crud_path = @full_path
            elsif (@action == :form)
                @widgets[:form].pk = params['edit'] if params['edit']
            end
        end
        
        def execute
            if (@action == :table)
                links = {}
                table_rows = @widgets[:table].scene.rows
                table_rows.each_index do |i|
                    links[i] = "#{@request_path}?_w"+params_for(self, :edit => table_rows[i][@key_element])
                end
                @widgets[:table].scene.links_to_form = links
            elsif (@action == :form)
                if (@widgets[:form].saved?)
                    flash[:saved] = true
                    redirect("#{@request.path}?_w"+params_for(self, :action => :table))
                end
            end
        end
        
    end
    
end; end