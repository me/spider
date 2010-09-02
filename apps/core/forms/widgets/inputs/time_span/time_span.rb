module Spider; module Forms
    
    class TimeSpan < Input
        
        def prepare_value(params)
            val = params['val']
            return nil unless val
            val = val.to_i
            case params['unit']
            when 'hours'
                val * 3600
            when 'min'
                val * 60
            else
                val
            end
            
        end
        
        def prepare_scene(scene)
            super
            val = self.value.to_i
            if val
                if val % 3600 == 0
                    scene.unit = 'hours'
                    scene.formatted_value = val / 3600
                elsif val % 60 == 0
                    scene.unit = 'min'
                    scene.formatted_value = val / 60
                else
                    scene.unit = 'sec'
                    scene.formatted_value = val
                end
            else
                scene.unit = 'min'
                scene.formatted_value = 0
            end
        end
        
    end
    
end; end