require 'apps/cas_server/models/ticket_granting_ticket'

module Spider; module CASServer; module Models
    
    class ServiceTicket < Ticket
        include Consumable
        
        element :ticket, String
        element :service, String
        element :consumed, DateTime
        element :client_hostname, String
        element :username, String
        element :type, String
        element :ticket_granting_ticket, Models::TicketGrantingTicket, :add_multiple_reverse => :service_tickets
        
        def matches_service?(service)
            CASServer::CAS.clean_service_url(self.service) == CASServer::CAS.clean_service_url(service)
        end
        
    end
    
end; end; end