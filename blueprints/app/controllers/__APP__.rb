<%= modules.inject(""){ |s, mod| s+= "module #{mod}; "} %>module Controllers
    
    class <%= module_name %>Controller < Spider::Controller
        layout '<%= app_name %>'
    
        def index
            puts "Rendering template<br>"
            @scene.msg = 'Hello!'
            render('index')
        end
    
    end
    
<%= modules.inject("") { |str, mod| str+= 'end; '} %>end