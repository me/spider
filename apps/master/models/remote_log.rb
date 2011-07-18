module Spider; module Master
    
    class RemoteLog < Spider::Model::Managed
        element :text, String
        element :level, String
        element :time, DateTime
        element :installation, Spider::Master::Installation, :add_multiple_reverse => :log
        element :acknowledged, Spider::Bool
    end
    
end; end