module Spider; module Worker
    
    class Job < Spider::Model::Managed
        element :uid, String
        element :description, String
        element :time, String
        element :task, String
        
    end
    
end; end