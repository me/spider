module Spider; module Forms
    
    class SearchSelect < Select
        tag 'search-select'
        i_attr_accessor :model
        is_attr_accessor :blank_option, :type => TrueClass, :default => true
        
        def prepare_value(params)
            return nil
        end

        
        # FIXME: change Select to avoid this
        def prepare_scene(scene)
            multi = @multiple
            @multiple = false
            scene = super
            @multiple = multi
            scene.multiple = @multiple
            scene.value_param = "#{scene.name}[value]"
            if (@multiple)
                scene.value_param += "[]"
            end
            scene.size ||= 40
            return scene
        end
        
        def prepare
            @modified = true
            self.value = params['value']
            if (params['clear'])
                self.value = nil
                @scene.next_step = :text
                @scene.clear = true
            end
            did_set_value = false
            @model = const_get_full(@model) if @model.is_a?(String)
            if (params['text'] && !params['text'].empty?)
                @data = @model.all
                @scene.text_query = params['text']
                cond = search_condition(params['text'])
                @data.condition = @data.condition.and(cond)
                if (@data.length == 0)
                    @scene.no_result = true
                    @scene.next_step = :text
                elsif (@data.length == 1)
                    set_or_add_value(@data[0])
                    did_set_value = true
                else
                    @scene.next_step = :select
                end
                @scene.clear = false
            end
            if (params['delete'])
                delete_keys = params['delete'].keys
                new_val = Spider::Model::QuerySet.new(@model)
                @value.each do |row|
                    new_val << row unless delete_keys.include?(row.keys_string)
                end
                @value = new_val
            end
            if (params['add'])
                add = params['add'].is_a?(Array) ? params['add'] : [params['add']]
                add.each do |a|
                    set_or_add_value(a)
                end
            end
            @done = false if @scene.next_step && !did_set_value
            @scene.delete_param = "_w#{param_name(self)}[delete]"
            @scene.value = @value
            @scene.list_value = @value
            if (@multiple && !@value)
                @scene.list_value = Spider::Model::QuerySet.static(@model)
            end
            @scene.keys = []
            if (@value)
                if (@multiple)
                    @value.each do |val|
                        @scene.keys << obj_to_key_str(val)
                    end
                else
                    @scene.key = obj_to_key_str(@value)
                end
            end
            @scene.data = @data
            super
        end
        
        def set_or_add_value(vals)
            vals = [vals] unless vals.is_a?(Array)
            vals.each do |val|
                unless val.is_a?(@model)
                    val = @model.new(val)
                end
                if (@multiple)
                    self.value ||= Spider::Model::QuerySet.new(@model)
                    self.value << val
                else
                    self.value = val
                end
            end
        end
        
        def run
            if (@value && !@multiple)
                @scene.value_desc = @value.to_s
            else
                @scene.next_step ||= :text
            end
            if (@value)
                @scene.selected = {}
                val = @multiple ? @value : [@value]
                val.each do |v|
                    @scene.selected[@model.primary_keys.map{|k| v.get(k) }.join(',')]
                end
            end
            if (@data)
                @scene.search_values = {}
                @data.each_index do |i|
                    @scene.search_values[i] = @model.primary_keys.map{|k| @data[i][k] }.join(',')
                end
                super
            end
        end
        
        def search_condition(q)
            cond = @model.free_query_condition(q)
            conn_cond = connection_condition
            return nil if conn_cond == false
            if (conn_cond)
                cond = cond.and(conn_cond)
            end
            # if (@value)
            #     @value.each do |v|
            #         k_cond = Spider::Model::Condition.or
            #         @model.primary_keys.each do |k| 
            #             k_cond[k].set(k, '<>', v.get(k))
            #         end
            #         cond.and(k_cond)
            #     end
            # els
            if (@request.params['not'])
                @request.params['not'].each do |v|
                    k_cond = Spider::Model::Condition.or
                    keys = v.split(',')
                    @model.primary_keys.each_index do |i| 
                        k = @model.primary_keys[i]
                        k_cond[k].set(k, '<>', keys[i])
                    end
                    cond = cond.and(k_cond)
                end
            end
            return cond
        end
                
        __.text
        def jquery_autocomplete
            cond = search_condition(@request.params['q'])
            return unless cond
            @search_results = @model.find(cond).limit(@request.params['limit'])
            @search_results.each do |row|
                $out << "#{row.to_s}|#{obj_to_key_str(row)}\n"
            end
        end

    end
    
end; end