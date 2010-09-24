module Spider; module Master
    
    class Command < Spider::Model::BaseModel
        remove_element :id
        element :id, UUID
        element :name, String
        element :arguments, Text
        element :status, {
            'pending' => 'Pending',
            'success' => 'Success',
            'failure' => 'Failure'
        }, :default => 'pending'
        element :executed, DateTime
        element :result, Text
    end
    
end; end