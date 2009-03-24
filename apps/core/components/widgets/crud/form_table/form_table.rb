module Spider; module Components
    
    class FormTable < Spider::Widget
        attr_accessor :owner, :owner_element
        
        def start
            @list = @owner[@owner_element]
            @widgets[:table].queryset = @list
        end
 
    end
    
end; end