<%= modules[0..-2].inject(""){ |s, mod| s+= "module #{mod}; "} %>module <%=modules[-1]%>
    
    class <%= module_name %>Controller < Spider::PageController
        
        layout '<%= app_name %>'
    
        __.html
        def index
            @scene.msg = 'Hello!'
            render('index')
        end
    
    end
    
<%= modules[0..-2].inject("") { |str, mod| str+= 'end; '} %>end