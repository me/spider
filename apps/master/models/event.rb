module Spider; module Master

    class Event < Spider::Model::Managed
        element :installation, Installation, :add_multiple_reverse => :events
        element :name, String
        element :details, Text
    end

end; end