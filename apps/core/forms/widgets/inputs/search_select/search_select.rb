module Spider; module Forms
    
    class SearchSelect < Select
        tag 'search-select'
        i_attr_accessor :model
        is_attr_accessor :blank_option, :type => TrueClass, :default => true
        
        def prepare_value(val)
            return nil
        end
        
        def prepare
            super
            if (params['clear'])
                @value = nil
                @scene.next_step = :text
            end
            if (params['text'] && !params['text'].empty?)
                @scene.text_query = params['text']
                cond = @model.free_query_condition(params['text'])
                @scene.data = @model.find(cond)
                if (@scene.data.length == 0)
                    @scene.no_result = true
                    @scene.next_step = :text
                elsif (@scene.data.length == 1)
                    self.value = @scene.data[0]
                else
                    @scene.next_step = :select
                end
            elsif (params['sel'])
                self.value = params['sel']
            end
            @done = false if @scene.next_step && !@value
        end
        
        def run
            if (@value)
                @scene.value_desc = @value.to_s
            else
                @scene.next_step ||= :text
            end
            if (@scene.data)
                @scene.values = {}
                debug("SELECT VALUE:")
                debug(@value)
                if (@value)
                    @scene.value_pks = @model.primary_keys.map{|k| @value.get(k) }.join(',')
                end
                @scene.data.each_index do |i|
                    @scene.values[i] = @model.primary_keys.map{|k| @scene.data[i][k] }.join(',')
                end
            end
            super
        end

    end
    
end; end