module Spider; module CASServer; module Models
    
    class TicketGrantingTicket < Ticket
        element :ticket, String
        element :client_hostname, String
        element :username, String
        element :extra_attributes, SerializedObject
        
        def extra_attributes
            super || {}
        end
        
    end
    
end; end; end