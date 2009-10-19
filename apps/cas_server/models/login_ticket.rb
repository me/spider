module Spider; module CASServer; module Models
    
    class LoginTicket < Ticket
        include Consumable
        
        element :ticket, String
        element :consumed, DateTime
        element :client_hostname, String
    end
    
end; end; end