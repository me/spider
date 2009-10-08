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
            return scene
        end
        
        def prepare
            self.value = params['value']
            if (params['clear'])
                self.value = nil
                @scene.next_step = :text
            end
            did_set_value = false
            if (params['text'] && !params['text'].empty?)
                @scene.text_query = params['text']
                cond = @model.free_query_condition(params['text'])
                @search_results = @model.find(cond)
                if (@search_results.length == 0)
                    @scene.no_result = true
                    @scene.next_step = :text
                elsif (@search_results.length == 1)
                    set_or_add_value(@search_results[0])
                    did_set_value = true
                else
                    @scene.next_step = :select
                end
            end
            if (params['delete'])
                new_val = Spider::Model::QuerySet.new(@model)
                @value.each do |row|
                    new_val << row unless row.keys_string == params['delete']
                end
                @value = new_val
            end
            @done = false if @scene.next_step && !did_set_value
            @scene.list_delete_param = "_w#{param_name(self)}[delete]="
            @scene.value = @value
            @scene.list_value = @value
            if (@multiple && !@value)
                @scene.list_value = Spider::Model::QuerySet.static(@model)
            end
            @scene.keys = []
            if (@value)
                if (@multiple)
                    @value.each do |val|
                        @scene.keys << @model.primary_keys.map{|k| val.get(k) }.join(',')
                    end
                else
                    @scene.key = @model.primary_keys.map{|k| @value.get(k) }.join(',')
                end
            end
            super
        end
        
        def set_or_add_value(vals)
            vals = [vals] unless vals.is_a?(Array)
            vals.each do |val|
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
            if (@search_results)
                @scene.search_results = @search_results
                @scene.search_values = {}
                @search_results.each_index do |i|
                    @scene.search_values[i] = @model.primary_keys.map{|k| @search_results[i][k] }.join(',')
                end
                super
            end
        end

    end
    
end; end