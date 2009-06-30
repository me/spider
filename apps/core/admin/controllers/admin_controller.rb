module Spider; module Admin
    
    class AdminController < Spider::PageController
        layout :spider_admin
        
        
        def index
            @response.headers['Content-Type'] = 'text/html'
            render 'index'
        end
        
    end
    
    
end; end