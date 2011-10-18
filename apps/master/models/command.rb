module Spider; module Master
    
    class Command < Spider::Model::Managed
        element :installation, Installation, :add_multiple_reverse => :commands
        element :uuid, UUID
        element :name, String
        element :arguments, Text
        element :status, {
            'pending' => 'Pending',
            'sent' => 'Sent',
            'success' => 'Success',
            'failure' => 'Failure',
            'not_done' => 'Not done'
        }, :default => 'pending'
        element :sent, DateTime
        element :done, DateTime
        element :result, Text
        
        def to_s
            "#{self.name} '#{self.arguments}' - #{self.status}"
        end
    end
    
end; end