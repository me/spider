module Spider; module Forms
    
    class SearchSelect < Select
        tag 'search-select'
        i_attr_accessor :model
        is_attr_accessor :blank_option, :type => TrueClass, :default => true
        
        def prepare_value(val)
            return nil
        end
        
        # FIXME: change Select to avoid this
        def prepare_scene(scene)
            multi = @multiple
            @multiple = false
            scene = super
            @multiple = multi
            scene.multiple = @multiple
            return scene
        end
        
        def prepare
            if (params['clear'])
                @value = nil
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
            elsif (params['sel'])
                set_or_add_value(params['sel'])
                did_set_value = true
            end
            @done = false if @scene.next_step && !did_set_value
            @scene.list_delete_param = "_w#{param_name(self)}[delete]"
            @scene.value = @value

            super
        end
        
        def set_or_add_value(val)
            if (@multiple)
                self.value ||= Spider::Model::QuerySet.new(@model)
                self.value << val
            else
                self.value = val
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